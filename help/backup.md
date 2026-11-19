# 备份与恢复记账数据

MoneyNote 是自托管的记账应用，你的账本、账户、流水全部存放在**你自己的服务器**上。这带来了隐私上的好处，也意味着**备份是你自己的责任**——没有第二个人能帮你把误删的数据找回来。

好消息是这件事并不复杂：MoneyNote 的数据本质上就是一份数据库文件（或一个数据库），把它复制出来就是备份。这篇文章教你把备份做对，并且养成习惯。

> 一句话版本：**停掉容器 → 打包 `data` 和 `config` 两个目录 → 启动容器**。把压缩包放到另一台机器或网盘上，就完成了一次完整备份。

## 一、先确认数据存在哪里

数据放在哪里，取决于你的部署方式和安装时选的数据库：

| 部署方式 | 数据实际位置 | 需要备份什么 |
| --- | --- | --- |
| Docker + 内嵌 H2（默认） | 宿主机部署目录下的 `data/<库名>.mv.db`，默认即 `data/moneynote.mv.db` | `data/` + `config/` 两个目录 |
| Docker + MySQL / PostgreSQL | 你自建的数据库服务里 | 数据库本身（用 `mysqldump` / `pg_dump`）+ `config/` |
| 源码本地运行 | `backend/` 运行目录下的 `data/` 与 `config/` | 同第一行 |

容器内的对应路径是 `/app/data` 和 `/app/config`，通过 Docker 挂载映射到宿主机。`config/db-config.properties` 记录了数据库类型、地址、账号和密码，是让服务"知道去哪找数据"的钥匙，**别只备份数据库而漏掉它**。

如果你不确定当时的挂载目录在哪，在部署机器上执行：

```bash
docker inspect moneynote --format '{{range .Mounts}}{{.Source}} -> {{.Destination}}{{"\n"}}{{end}}'
```

输出里每一行的前半段（箭头左边）就是宿主机上的真实路径。

## 二、备份里到底有什么

一次完整备份包含：

* 用户账号与登录信息
* 账本、账户、币种
* 分类、标签、交易对象
* 全部记账流水与转账记录
* 提醒事项
* AI 助手的模型配置（**包含 API Key**）

不包含：浏览器缓存、客户端的本地界面设置、服务日志。这些都不影响数据本身。

因为备份文件里有账号密码和 API Key，**它和你的密码本一样敏感**：不要随手丢在公共网盘目录里，上传前建议先加密码压缩。

## 三、方案一：内嵌 H2（默认，大多数用户）

### 3.1 冷备份：停服务再打包（推荐）

H2 是嵌入式数据库，数据在运行时会留在内存里，直到合适的时机才写回磁盘。**服务运行中直接复制 `.mv.db` 文件，可能拿到一份半新半旧的快照**，恢复后表现为"最近几笔账不见了"，很难排查。所以最稳妥的方式是先停服务。

在部署目录（有 `docker-compose.yml` 的那一层）执行：

```bash
# 1. 停止服务，等待数据落盘
docker stop moneynote

# 2. 打包数据与配置
tar -czf "moneynote-backup-$(date +%Y%m%d-%H%M).tar.gz" data config

# 3. 启动服务
docker start moneynote
```

用 Compose 部署的话，`docker compose stop` / `docker compose start` 等价。容器名默认是 `moneynote`，如果你当初用 `--name` 改过，下面所有命令里换成你自己的名字。

Windows（PowerShell）版本：

```powershell
docker stop moneynote
Compress-Archive -Path .\data, .\config -DestinationPath ".\moneynote-backup-$(Get-Date -Format yyyyMMdd-HHmm).zip"
docker start moneynote
```

整个过程中断服务通常只有几秒，个人使用完全无感。

> 停止时请用 `docker stop`，不要用 `docker kill`。前者会通知应用优雅关闭、把缓存写入磁盘；后者是直接断电，对小概率的数据文件有风险。

### 3.2 热备份：通过 H2 控制台导出 SQL（不停机）

如果不想中断服务，可以用 H2 自带的逻辑导出，把整个库导成一份 SQL 文本。

**先过第一关：控制台默认只允许本机访问。** 如果你从自己的电脑直接打开 `http://<服务器IP>:9096/h2-console`，会看到：

```text
Sorry, remote connections ('webAllowOthers') are disabled on this server.
```

这不是故障，是 H2 出厂就带的防护——控制台没有登录校验，一旦对公网开放，等于把整个数据库交给扫描器。推荐用 SSH 隧道绕过去，让请求从服务器本机发出：

```bash
# 在自己电脑上执行：本地 9097 转发到服务器的 127.0.0.1:9096
ssh -L 9097:127.0.0.1:9096 root@<服务器IP>
```

保持这个窗口开着，浏览器访问 `http://localhost:9097/h2-console` 即可正常打开，不需要改任何配置，也不向公网暴露控制台。

确实没有 SSH 条件时，才考虑给容器加环境变量放行远程访问。容器需要**重建**才生效，并且必须在当初部署的那个目录下执行（`$(pwd)` 指向别处会起一个空库）：

```bash
docker rm -f moneynote
docker run -d --name moneynote --restart unless-stopped -p 9096:9096 \
  -v $(pwd)/data:/app/data -v $(pwd)/config:/app/config \
  -e SPRING_H2_CONSOLE_SETTINGS_WEB_ALLOW_OTHERS=true \
  markliu2018/moneynote:latest
```

用 Compose 则在服务下加 `environment: { SPRING_H2_CONSOLE_SETTINGS_WEB_ALLOW_OTHERS: "true" }`，再 `docker compose up -d`。**这是一项真实的暴露风险**：控制台默认 URL、账号 `sa`、空密码，任何人都能在上面读写甚至删表。开启时必须同时用防火墙/安全组把 9096 限制为你自己的 IP，备份完立刻去掉这个变量并重建容器。

接下来是控制台里的操作（走隧道就用 `http://localhost:9097/h2-console`）：

1. JDBC URL 填下面这串（和服务内部使用的连接参数保持一致，参数不能省略）：

   ```text
   jdbc:h2:file:/app/data/moneynote;MODE=MySQL;DATABASE_TO_LOWER=TRUE;CASE_INSENSITIVE_IDENTIFIERS=TRUE;AUTO_SERVER=TRUE
   ```

   库名不是 `moneynote` 的话，把路径里的 `moneynote` 换成你的。
2. 用户名 `sa`，密码留空，点击连接。
3. 在 SQL 框里执行：

   ```sql
   SCRIPT TO '/app/data/backup-20261119.sql'
   ```

4. 把文件取出来：

   ```bash
   docker cp moneynote:/app/data/backup-20261119.sql .
   ```

`SCRIPT TO` 导出的是完整的建表语句加数据，属于逻辑备份，跨版本恢复的兼容性比直接拷文件更好。缺点是文件比 `.mv.db` 大，数据量大时导出也慢一些。

如果连接时报 `Database may be already in use`，说明这个实例的 H2 不允许从外部进程接入，改用 3.1 的冷备份即可。

> 备份做完就关掉 SSH 隧道；如果用方案二放开了远程访问，记得立刻去掉环境变量并重建容器，别让它一直开着。

### 3.3 恢复 H2 备份

恢复的原则是：**先把现状留一份，再覆盖**。这样万一压缩包有问题，还能退回去。

```bash
docker stop moneynote

# 把现在的数据挪开，不要直接删
mv data data.bak-$(date +%Y%m%d-%H%M)
mv config config.bak-$(date +%Y%m%d-%H%M)

# 解压备份（会重新生成 data/ 和 config/）
tar -xzf moneynote-backup-20261119-0930.tar.gz

docker start moneynote
```

启动后刷新页面、登录，确认最近的流水、账户余额是否正确。

有两个细节容易踩到：

* **库名要一致**。H2 的数据文件名由 `config/db-config.properties` 里的 `db.name` 决定，备份时的库名和恢复后的库名必须相同，否则服务会去创建一个空库，表现为"数据全没了"。
* **不要只恢复 `data/` 而用旧的 `config/`**（或反过来）。两者是同一次部署的产物，最好成对恢复。

如果只做了 SQL 逻辑备份，恢复方式是：启动服务后进 H2 控制台，执行

```sql
RUNSCRIPT FROM '/app/data/backup-20261119.sql'
```

## 四、方案二：MySQL / PostgreSQL

使用外部数据库时，数据不在 Docker 目录里，备份要用数据库自带的工具。这类工具支持在线热备，不需要停 MoneyNote。

### 4.1 备份

MySQL（InnoDB）：

```bash
mysqldump -h 127.0.0.1 -P 3306 -u root -p \
  --single-transaction --routines --triggers \
  moneynote > "moneynote-$(date +%Y%m%d).sql"
```

`--single-transaction` 让导出在一个一致性快照里完成，不会锁表影响正在使用的人。

PostgreSQL：

```bash
pg_dump -h 127.0.0.1 -p 5432 -U postgres -Fc \
  -f "moneynote-$(date +%Y%m%d).dump" moneynote
```

`-Fc` 是自定义压缩格式，比纯 SQL 小，恢复也更快。

同时别忘了把 `config/db-config.properties` 一起备份——恢复时你会需要里面的连接信息。

### 4.2 恢复

MySQL：

```bash
mysql -h 127.0.0.1 -P 3306 -u root -p moneynote < moneynote-20261119.sql
```

PostgreSQL：

```bash
pg_restore -h 127.0.0.1 -p 5432 -U postgres \
  -d moneynote --clean --if-exists moneynote-20261119.dump
```

恢复完成后重启 MoneyNote 容器即可。

## 五、换服务器 / 迁移数据

内嵌 H2 的迁移非常直接：

1. 按 3.1 做一次冷备份。
2. 在新服务器上准备好部署目录，把压缩包拷过去并解压。
3. 用原来的 `docker run` 或 `docker compose up -d` 启动。

因为 `config` 里的路径是相对路径，`data` 里的文件名也是固定的，换机器、换目录都不影响。

使用 MySQL / PostgreSQL 时，先把 dump 导入新数据库，再处理配置。这里有一个坑：**已配置完成的实例不允许在页面上重新配置数据库**（`/setup` 会被拦截，防止误操作换库）。要指向新的数据库地址，需要：

```bash
docker stop moneynote
mv config/db-config.properties config/db-config.properties.old
docker start moneynote
```

重启后会重新进入安装向导，填新数据库的地址和账号即可。原来的数据在数据库里，不会被向导清空。

## 六、多久备一次，留几份

备份的价值不在于"做过"，而在于"需要时有一份能用的"。建议：

* **频率**：每天都在记账的话，每天一次；一周记两三次的话，每周一次也够。另外在两个时间点额外手动备一次——**升级镜像之前**和**批量整理账本（改分类、删账本）之前**。
* **保留**：最近 7～14 天的每日备份 + 每月 1 份长期备份，足够应付"记错了几天才发现"的情况。
* **存放**：遵循 3-2-1 原则——至少 3 份副本、2 种介质（本机硬盘 + 移动硬盘/NAS）、1 份放在异地（网盘或另一台机器）。只存在同一块硬盘上的备份，硬盘坏的时候会一起消失。

## 七、把备份自动化

手工备份迟早会忘。让系统替你执行。

### 7.1 Linux（cron）

把下面的脚本保存为 `~/backup-moneynote.sh`，`chmod +x` 后加进 crontab：

```bash
#!/bin/sh
# 每天 03:30 备份一次，保留最近 14 天
set -eu

DEPLOY_DIR="/opt/moneynote"          # 改成你的部署目录
BACKUP_DIR="/mnt/backup/moneynote"   # 改成备份存放位置

mkdir -p "$BACKUP_DIR"
cd "$DEPLOY_DIR"

docker stop moneynote
# 打包中途失败也要把服务拉起来，别让网站一直停着
trap 'docker start moneynote' EXIT

tar -czf "$BACKUP_DIR/moneynote-$(date +%Y%m%d).tar.gz" data config

# 删除 14 天前的备份
find "$BACKUP_DIR" -name 'moneynote-*.tar.gz' -mtime +14 -delete
```

```bash
# 每天 03:30 执行
30 3 * * * /home/你的用户名/backup-moneynote.sh >> /var/log/moneynote-backup.log 2>&1
```

如果用的是 MySQL / PostgreSQL，把中间三行换成对应的 `mysqldump` / `pg_dump`，就不需要停服务了。

### 7.2 Windows（任务计划程序）

保存为 `backup-moneynote.ps1`：

```powershell
$deploy  = "C:\moneynote"
$backup  = "D:\backup\moneynote"
New-Item -ItemType Directory -Force -Path $backup | Out-Null

docker stop moneynote
try {
    Compress-Archive -Path "$deploy\data", "$deploy\config" `
      -DestinationPath "$backup\moneynote-$(Get-Date -Format yyyyMMdd).zip" -Force
}
finally {
    # 压缩失败也要把服务拉起来
    docker start moneynote
}

# 保留最近 14 份
Get-ChildItem "$backup\moneynote-*.zip" |
  Sort-Object LastWriteTime -Descending |
  Select-Object -Skip 14 |
  Remove-Item -Force
```

然后在"任务计划程序"里新建任务，触发器设为每天固定时间，操作选"启动程序"，程序填 `powershell.exe`，参数填 `-ExecutionPolicy Bypass -File "C:\path\backup-moneynote.ps1"`。

## 八、验证备份（最容易被跳过的一步）

一份从没被打开过的备份，只能算"以为有备份"。

* 备份完成后确认压缩包大小不是 0，且和上一次相比没有突然缩水一大截。
* 每月或每季度做一次恢复演练：把备份解压到**另一个目录**，用另一个容器名和端口（如 `--name moneynote-test -p 9097:9096`）起一份临时实例，登录看数据是否完整。演练时不要让它和正式实例共用同一份 `data`，也不要让它对外提供访问；确认无误后 `docker rm -f moneynote-test` 删掉。
* 演练时重点看三样东西：最近的流水在不在、账户余额对不对、分类和标签有没有丢。

## 九、常见问题

**打开 `/h2-console` 提示 `Sorry, remote connections ('webAllowOthers') are disabled`？**
正常现象，控制台默认只接受服务器本机的访问。用 3.2 里的 SSH 隧道即可，不必改配置；如果确实要直接开放，需要给容器加 `SPRING_H2_CONSOLE_SETTINGS_WEB_ALLOW_OTHERS=true` 并重建容器，同时务必用安全组限制来源 IP。

**升级镜像会不会丢数据？**
不会。`data` 和 `config` 挂在容器外面，`docker pull` 新镜像、`docker rm -f` 旧容器、再用同样的命令重建，数据都还在。但升级前顺手备一份仍然值得，万一新版本有问题可以立刻回退。

**直接让网盘同步 `data` 目录行不行？**
不建议。同步工具会尝试上传正在被 H2 写入的文件，容易产生冲突副本或半截文件。正确做法是把**备份压缩包**放进同步目录，而不是同步运行中的数据库目录。

**`docker compose down -v` 会删掉我的数据吗？**
这里的 `data`、`config` 是宿主机目录挂载，不是 Docker 命名卷，`down -v` 不会删除它们。但**永远不要手写 `rm -rf data`**——那才是真的删除。

**`.mv.db` 文件拷出来双击打不开？**
它是 H2 的私有格式，需要用 H2 工具打开，且版本要匹配。查看内容时用 H2 控制台连上去看，或者干脆用 `SCRIPT TO` 导出成 SQL 再读。

**恢复后数据停在几天前？**
说明用的是较早的备份包，属正常现象。这也是为什么要每天备份——备份越勤，最坏情况下丢的数据越少。

**备份文件多大算正常？**
和你的流水数量成正比。纯文本的记账数据压缩率很高，几千条流水通常只有几 MB。如果某天体积突然翻了很多倍，检查一下是不是把 `data` 目录里的 SQL 导出文件或旧压缩包也一并打进去了。

## 十、备份检查清单

第一次配置备份时，照着走一遍：

- [ ] 确认了容器实际挂载的 `data`、`config` 目录位置
- [ ] 完成了一次冷备份，压缩包大小正常
- [ ] 备份包已复制到另一块硬盘或网盘，不只是留在同一台机器
- [ ] 设置了定时任务，并手动触发一次确认能跑通
- [ ] 做过一次恢复演练，确认能登录且数据完整
- [ ] 记下了备份文件的位置和恢复命令（就存在这篇文章旁边）

做完这六项，你的记账数据才算真正安全。
