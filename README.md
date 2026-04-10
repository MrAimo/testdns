# TestDNS

## 项目描述
TestDNS 是一个用于测试域名系统 (DNS) 配置和功能的项目。该项目旨在帮助开发者和网络管理员快速诊断和解决 DNS 相关问题。支持 Linux/macOS 和 Windows 两个平台。

## 功能特性
- ✅ 快速 DNS 查询测试
- ✅ 支持多种记录类型（A、AAAA、MX、CNAME 等）
- ✅ 详细的诊断报告
- ✅ 易于使用的命令行界面
- ✅ 跨平台支持（Linux/macOS/Windows）
- ✅ 支持自定义 DNS 服务器
- ✅ 支持导出 CSV 报告

## 项目结构
```
testdns/
├── dnstest.sh        # Linux/macOS DNS 测试脚本（Bash）
├── dnstest.ps1       # Windows DNS 测试脚本（PowerShell）
├── README.md         # 项目说明
└── domains.txt       # 域名列表示例（可选）
```

## 安装
```bash
git clone https://github.com/MrAimo/testdns.git
cd testdns
```

## 使用方法

### Linux / macOS
使用 Bash 脚本进行 DNS 测试：

```bash
# 基础使用
./dnstest.sh

# 指定 DNS 服务器
./dnstest.sh -d 8.8.8.8 -d 1.1.1.1

# 指定查询类型
./dnstest.sh -r A

# 从文件读取域名列表
./dnstest.sh -f domains.txt

# 导出结果为 CSV
./dnstest.sh -o results.csv

# 按查询时间排序
./dnstest.sh -s time

# 组合使用
./dnstest.sh -d 8.8.8.8 -f domains.txt -o results.csv -s time
```

**脚本选项说明：**
- `-d DNS_SERVER` - 指定 DNS 服务器（可多次指定）
- `-t TIMEOUT` - 超时时间（秒），默认 2 秒
- `-r TYPE` - 查询类型：A、AAAA、ALL，默认为 ALL
- `-f FILE` - 从文件读取域名列表
- `-o FILE.csv` - 导出结果为 CSV 文件
- `-s domain|time` - 排序方式：按域名或按耗时
- `-h` - 显示帮助信息

### Windows
使用 PowerShell 脚本进行 DNS 测试：

```powershell
# 基础使用
.\dnstest.ps1 -Domain "example.com"

# 示例：测试百度
.\dnstest.ps1 -Domain "www.baidu.com"
```

**前提条件：**
- 需要 PowerShell 3.0 或更高版本
- 如果遇到执行策略问题，请运行：
  ```powershell
  Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
  ```

## 示例输出

**Linux/macOS 输出示例：**
```
================================================================================
DNS 解析测试 (优化版)
域名数量: 20
DNS: 8.8.8.8 1.1.1.1
记录类型: A AAAA
================================================================================

域名                           DNS服务器       类型     解析IP                                        耗时       状态
----------------------------------------------------------------------------------------------------
www.baidu.com                  8.8.8.8         A        39.156.66.18,39.156.66.10                    45ms       OK
www.baidu.com                  1.1.1.1         A        39.156.66.18,39.156.66.10                    38ms       OK
...

================================================================================
统计汇总:
DNS: 8.8.8.8
  A 记录: 成功20次, 最小12ms, 最大156ms, 平均45ms
  AAAA 记录: 成功18次, 最小8ms, 最大89ms, 平均32ms
DNS: 1.1.1.1
  A 记录: 成功20次, 最小10ms, 最大134ms, 平均38ms
  AAAA 记录: 成功19次, 最小6ms, 最大76ms, 平均28ms
================================================================================
```

## 依赖要求

**Linux/macOS：**
- Bash 4.0+
- dig (dnsutils / bind-utils)

**Windows：**
- PowerShell 3.0+
- 内置 Resolve-DnsName cmdlet（Windows 8+ / Server 2012+）

## 常见问题

**Q: dig 命令未找到？**
A: 请安装对应的包：
- Debian/Ubuntu: `sudo apt-get install dnsutils`
- CentOS/RHEL: `sudo yum install bind-utils`
- macOS: `brew install bind`

**Q: PowerShell 脚本无法执行？**
A: 检查执行策略并修改：
```powershell
Get-ExecutionPolicy
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**Q: 如何自定义测试域名？**
A: 创建 `domains.txt` 文件，每行一个域名，然后使用 `-f domains.txt` 参数。

## 许可证
MIT License

## 联系方式
如有问题或建议，欢迎提交 Issue 或 Pull Request。