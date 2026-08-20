# 插件测试

在项目根目录运行：

```powershell
Get-ChildItem tests -Filter *.ps1 | ForEach-Object {
  powershell -NoProfile -ExecutionPolicy Bypass -File $_.FullName
}
```

测试覆盖 bundle manifest、Web 参数组合和临时 profile 安全清理。测试使用临时目录，并在完成后清理。
