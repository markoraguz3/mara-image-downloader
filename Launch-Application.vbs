Set shell = CreateObject("WScript.Shell")
scriptDirectory = CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName)
shell.Run """" & scriptDirectory & "\Pokreni.bat""", 0, False
