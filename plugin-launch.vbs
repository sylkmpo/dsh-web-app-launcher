' Hidden Windows entry point for the dsh.bundle desktop shortcut.
Set sh = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
base = fso.GetParentFolderName(WScript.ScriptFullName) & "\"
sh.Run "cmd /c """ & base & "plugin-run.bat""", 0, False
