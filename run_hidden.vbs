If WScript.Arguments.Count > 0 Then
    Dim shell, fso, psExe, cmd
    Set shell = CreateObject("WScript.Shell")
    Set fso = CreateObject("Scripting.FileSystemObject")
    If fso.FileExists("C:\Program Files\PowerShell\7\pwsh.exe") Then
        psExe = """C:\Program Files\PowerShell\7\pwsh.exe"""
    Else
        psExe = """C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"""
    End If
    cmd = psExe & " -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File """ & WScript.Arguments(0) & """"
    If WScript.Arguments.Count > 1 Then
        cmd = cmd & " " & WScript.Arguments(1)
    End If
    shell.Run cmd, 0, True
End If
