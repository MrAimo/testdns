# TestDNS

## 项目描述
TestDNS 是一个用于测试域名系统 (DNS) 配置和功能的项目。该项目旨在帮助开发者和网络管理员快速诊断和解决 DNS 相关问题。

## 功能特性
- 快速 DNS 查询测试
- 支持多种记录类型（A、AAAA、MX、CNAME 等）
- 详细的诊断报告
- 易于使用的命令行界面

## 项目结构
```
testdns/
├── scripts/          # 脚本文件
├── tests/            # 测试文件
├── README.md         # 项目说明
└── requirements.txt  # 依赖列表
```

## 安装
```bash
git clone https://github.com/MrAimo/testdns.git
cd testdns
```

## 使用方法
```bash
./dns_test.sh example.com
```

## 许可证
MIT License

## 联系方式
如有问题或建议，欢迎提交 Issue 或 Pull Request。