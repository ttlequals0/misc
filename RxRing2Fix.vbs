'* This script will set RxRing#2 to a esxi compatible value of 2048.

Const HKEY_LOCAL_MACHINE = &H80000002
Dim sPath, aSub, sKey, objFSO, objFile, strValueName, strValue, strComputer, outFile, objReg
outFile = ".\RxRing2Fix.txt"
Set objFSO=CreateObject("Scripting.FileSystemObject")
Set objFile = objFSO.CreateTextFile(outFile,True)
sPath = "SYSTEM\CurrentControlSet\Control\Class\{4D36E972-E325-11CE-BFC1-08002BE10318}\"
strValueName = "MaxRxRing2length"
strValue = "2048"
strComputer = "."
Set objReg=GetObject("winmgmts:{impersonationLevel=impersonate}!\\"&_ 
    strComputer & "\root\default:StdRegProv")
objReg.EnumKey HKEY_LOCAL_MACHINE, sPath, aSub

Sub rx2fix()    
    For Each sKey In aSub
        If NOT sKey = "Properties" Then
            Return = objReg.SetStringValue(HKEY_LOCAL_MACHINE,sPath & "\" & sKey,strValueName,strValue)
            If (Return = 0) And (Err.Number = 0) Then
                objFile.Write sKey + " updated = Success" & vbCrLf
             Else
                objFile.Write sKey + " update = Failed. Error = " & Err.Number
            End If
        End If
    Next
End Sub

rx2fix()
