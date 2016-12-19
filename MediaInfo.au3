#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Icon=icon.ico
#AutoIt3Wrapper_UseX64=y
#AutoIt3Wrapper_Res_Comment=MediaInfo
#AutoIt3Wrapper_Res_Description=MediaInfoAu
#AutoIt3Wrapper_Res_Fileversion=2015.12.18.1
#AutoIt3Wrapper_Res_Language=1033
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#include <EditConstants.au3>
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <Array.au3>
#include <FontConstants.au3>

; ***** aaccxx@x.ip6.li
;~ Gremlin - Lester1982
;~ rock12@yopmail.com : qwerty123

$sFileVersion = FileGetVersion("MediaInfo.dll")

GUICreate("MediaInfo " & $sFileVersion, 600, 600, -1, -1, $WS_SIZEBOX, $WS_EX_ACCEPTFILES)

If $CmdLine[0] > 0 Then
	$_file = $CmdLine[1]
Else
	$_file = ""
EndIf

Local $info = GUICtrlCreateEdit("", 0, 0, 598, 575, $ES_AUTOVSCROLL + $WS_VSCROLL + $ES_READONLY)
If $_file <> "" Then
	$data = _ArrayToString(_MediaInfo($_file, ""), @CRLF)
	GUICtrlSetData($info, $data)
EndIf

GUICtrlSetState(-1, $GUI_DROPACCEPTED)
GUICtrlSetFont($info, 9, $FW_DONTCARE, $GUI_FONTNORMAL, "Consolas")
GUICtrlSetState($info, $GUI_FOCUS)


Local $idContextmenu = GUICtrlCreateContextMenu()
Local $idOpen = GUICtrlCreateMenuItem("Open", $idContextmenu)
GUICtrlCreateMenuItem("", $idContextmenu) ; separator
Local $idMenuLite = GUICtrlCreateMenuItem("Short info", $idContextmenu)
Local $idMenuFull = GUICtrlCreateMenuItem("Full info", $idContextmenu)
Local $idSave = GUICtrlCreateMenuItem("Save logfile", $idContextmenu)
GUICtrlCreateMenuItem("", $idContextmenu) ; separator
Local $idMenuInfo = GUICtrlCreateMenuItem("About", $idContextmenu)

GUISetState(@SW_SHOW)

While 1
	Switch GUIGetMsg()
		Case $GUI_EVENT_CLOSE
			ExitLoop
		Case $idMenuFull
			$data = _ArrayToString(_MediaInfo($_file, "1"), @CRLF)
			GUICtrlSetData($info, $data)
		Case $idMenuLite
			$data = _ArrayToString(_MediaInfo($_file, ""), @CRLF)
			GUICtrlSetData($info, $data)
		Case $idMenuInfo
			MsgBox(0, " About MediaInfoKK", "Vytvořil Krakatoa" & @CRLF & "http://krakatoa.www3.cz/")
		Case $GUI_EVENT_DROPPED
			If @GUI_DropId = $info Then
				$_file = @GUI_DragFile
				$data = _ArrayToString(_MediaInfo($_file, ""), @CRLF)
				GUICtrlSetData($info, $data)
			EndIf
		Case $idOpen
			$_file_tmp = FileOpenDialog("Open", @HomeDrive, "All (*.*)")
			If Not @error Then
				$_file = $_file_tmp
				$data = _ArrayToString(_MediaInfo($_file, ""), @CRLF)
				GUICtrlSetData($info, $data)
			EndIf
		Case $idSave
			$sFilePath = FileSaveDialog("Save", @HomeDrive, "Log (*.txt)", "log")
			If Not @error Then
				Local $hFileOpen = FileOpen($sFilePath, 2)
				If Not @error Then FileWrite($hFileOpen, $data)
			EndIf
	EndSwitch
WEnd

Func _MediaInfo($_file, $complete)

	Local $__MediaInfo, $__MediaInfoHandle
	Local $_Inform, $_Return

	If @AutoItX64 Then
		$__MediaInfo = DllOpen("MediaInfo64.dll")
	Else
		$__MediaInfo = DllOpen("MediaInfo.dll")
	EndIf

	$__MediaInfoHandle = DllCall($__MediaInfo, "ptr", "MediaInfo_New")
	DllCall($__MediaInfo, "int", "MediaInfo_Open", "ptr", $__MediaInfoHandle[0], "wstr", $_file)
	DllCall($__MediaInfo, "wstr", "MediaInfo_Option", "ptr", 0, "wstr", "Complete", "wstr", $complete)
	$_Inform = DllCall($__MediaInfo, "wstr", "MediaInfo_Inform", "ptr", $__MediaInfoHandle[0], "int", 0)
	DllCall($__MediaInfo, "int", "MediaInfo_Close", "ptr", $__MediaInfoHandle[0])
	DllCall($__MediaInfo, "none", "MediaInfo_Delete", "ptr", $__MediaInfoHandle[0])
	DllClose($__MediaInfo)

	$_Return = StringSplit($_Inform[0], @LF)
	_ArrayDisplay($_Return)
	If @error Then
		Return 0
	Else
		Return $_Return
	EndIf
EndFunc   ;==>_MediaInfo
