#include <GDIPlus.au3>
#include <GUIConstantsEx.au3>
#include <GUIButton.au3>
#include <WindowsConstants.au3>
#include <MsgBoxConstants.au3>
#include <Misc.au3>
#include <Array.au3>
#include <File.au3>
#include <String.au3>
#include <Winapi.au3>
#include <GuiStatusBar.au3>
#include <Process.au3>
#include <constants.au3>


AutoItSetOption("MustDeclareVars", 1)
AutoItSetOption("GUIOnEventMode", 1)
Opt("WinTitleMatchMode", 2)

;~ mtn -c 1 -r 1 -D 0 -O thumbs -i F:\jb\3
;~ ffmpeg -i in.avi -ss 15 -vf thumbnail,scale=320:200 -frames:v 1 out.png


Global $hMainImage, $hCompImage
Global $sFile, $sPath1, $sPath2, $aFilesToCompare, $FileName, $sFileMain, $aCollectionFiles, $sFileNameMain, $sFileNameComp, $aDeletableFiles, $iMntPID, $sLine
Global $iMaxLum_Main = 0, $iMaxLum_Comp = 0, $iSize, $iHistMatches = 0, $fMatchOverall = 0, $iSCIndex_Main = 0
Global $tChannel_Main, $tChannel_Comp
Global $aHistogramFormat[] = [$GDIP_HistogramFormatGray, $GDIP_HistogramFormatR, $GDIP_HistogramFormatG, $GDIP_HistogramFormatB], $Format, $i, $iHandleCounter
Global $hGui, $hGraphics, $hThumbMain, $hThumbComp, $hOKButton, $hLabel, $bWait, $hName1, $hName2, $hTemp, $hStatus, $Timer, $hLogFile, $iRunningTime, $iLoopTime, $Counter, $iTimePerPicture, $bSingleDir = False

Global $aCompSize[4][2] = [[160, 120],[320, 240],[480, 360],[640, 480]]
Global $fNormFact, $iSens = 150, $iMatchThreshold = 80, $iCompSize = 2, $iInteractive = 0, $iKillThresh = 100, $iSCThresh = 180

If Not _GDIPlus_Startup() Then
	MsgBox($MB_SYSTEMMODAL, "ERROR", "GDIPlus.dll v1.1 not available")
	Exit
EndIf

$hGui = GUICreate("DupeFinder", 280, 170)
$hStatus = _GUICtrlStatusBar_Create($hGui, -1, "")
$hGraphics = _GDIPlus_GraphicsCreateFromHWND($hGui)
GUISetOnEvent($GUI_EVENT_CLOSE, "_Exit")
GUISetOnEvent($GUI_EVENT_RESTORE, "_Redraw")
$hName1 = GUICtrlCreateLabel("", 15, 95, 115, 20)
$hName2 = GUICtrlCreateLabel("", 155, 95, 115, 20)
$hOKButton = GUICtrlCreateButton("OK", 10, 110, 30, 20)
GUICtrlSetOnEvent($hOKButton, "_Continue")
$hLabel = GUICtrlCreateLabel("", 55, 110, 200, 20)
GUIRegisterMsg($WM_PAINT, "_Redraw")
GUIRegisterMsg($WM_ERASEBKGND, "_Redraw")
GUISetState(@SW_SHOW)

$hLogFile = FileOpen(@ScriptDir & "\dupefinder.log", 2)

$sPath1 = FileSelectFolder("select collection folder", "", 1, "", $hGui)
If @error Then _Exit()

$sPath2 = FileSelectFolder("select a folder to compare", "", 1, $sPath1, $hGui)
If @error Then _Exit()

_GUICtrlStatusBar_SetText($hStatus, "Creating Collection Thumbnails")
_ThumbNailer($sPath1, "temp1")
$aCollectionFiles = _FileListToArrayRec(@ScriptDir & "\temp1", "*.jpg", 1, 1, 0, 2)
$aCollectionFiles[0] = Int($aCollectionFiles[0])

If $sPath1 == $sPath2 Then
	$bSingleDir = True
	$aFilesToCompare = _FileListToArrayRec(@ScriptDir & "\temp1", "*.jpg", 1, 1, 0, 2)
Else
	_GUICtrlStatusBar_SetText($hStatus, "Creating Compare Thumbnails")
	_ThumbNailer($sPath2, "temp2")
	$aFilesToCompare = _FileListToArrayRec(@ScriptDir & "\temp2", "*.jpg", 1, 1, 0, 2)
EndIf

Global $aFTCHandles[Int($aFilesToCompare[0])]

For $i = 1 To Int($aFilesToCompare[0])
	$aFTCHandles[$i - 1] = _GDIPlus_ImageLoadFromFile($aFilesToCompare[$i])
Next

_GUICtrlStatusBar_SetText($hStatus, "")

For $sFileMain In $aCollectionFiles

	If IsInt($sFileMain) Then ContinueLoop

	$hTemp = _GDIPlus_ImageLoadFromFile($sFileMain)
	$hMainImage = _GDIPlus_ImageResize($hTemp, $aCompSize[$iCompSize][0], $aCompSize[$iCompSize][1])
	_GDIPlus_ImageDispose($hTemp)

	$sFileNameMain = _StringExplode($sFileMain, "\")
	$sFileNameMain = $sFileNameMain[UBound($sFileNameMain) - 1]

	$hThumbMain = _Thumb($hMainImage)
	_GDIPlus_GraphicsDrawImage($hGraphics, $hThumbMain, 10, 10)
	_WinAPI_RedrawWindow($hGUI, 0, 0, $RDW_VALIDATE)
	GUICtrlSetData($hName1, $sFileNameMain)

	$Timer = TimerInit()
	If $bSingleDir Then
		_ArrayDelete($aFilesToCompare, 1)
		_ArrayDelete($aFTCHandles, 0)
	EndIf
	$iHandleCounter = 0
	For $sFile In $aFilesToCompare

		If IsInt($sFile) Then ContinueLoop

		$hCompImage = _GDIPlus_ImageResize($aFTCHandles[$iHandleCounter], $aCompSize[$iCompSize][0], $aCompSize[$iCompSize][1])

		$sFileNameComp = _StringExplode($sFile, "\")
		$sFileNameComp = $sFileNameComp[UBound($sFileNameComp) - 1]

		$hThumbComp = _Thumb($hCompImage)
		_GDIPlus_GraphicsDrawImage($hGraphics, $hThumbComp, 150, 10)
		_WinAPI_RedrawWindow($hGUI, 0, 0, $RDW_VALIDATE)
		GUICtrlSetData($hName2, $sFileNameComp)

		; Compare Channels
		$fMatchOverall = 0
		$iSCIndex_Main = 0
		For $Format In $aHistogramFormat
			$iSize = _GDIPlus_BitmapGetHistogramSize($Format)

			$tChannel_Main = DllStructCreate("uint[" & $iSize & "];")
			_GDIPlus_BitmapGetHistogram($hMainImage, $Format, $iSize, $tChannel_Main)
			$iMaxLum_Main = 0
			For $i = 1 To $iSize
				If DllStructGetData($tChannel_Main, 1, $i) > $iMaxLum_Main Then $iMaxLum_Main = DllStructGetData($tChannel_Main, 1, $i)
				If DllStructGetData($tChannel_Main, 1, $i) == 0 Then $iSCIndex_Main += 1
			Next

			$tChannel_Comp = DllStructCreate("uint[" & $iSize & "];")
			_GDIPlus_BitmapGetHistogram($hCompImage, $Format, $iSize, $tChannel_Comp)
			$iMaxLum_Comp = 0
			For $i = 1 To $iSize
				If DllStructGetData($tChannel_Comp, 1, $i) > $iMaxLum_Comp Then $iMaxLum_Comp = DllStructGetData($tChannel_Comp, 1, $i)
			Next

			$fNormFact = $iMaxLum_Comp / $iMaxLum_Main

			$iHistMatches = 0
			For $i = 1 To $iSize
				If Abs(DllStructGetData($tChannel_Main, 1, $i) * $fNormFact - DllStructGetData($tChannel_Comp, 1, $i)) < $iSens Then $iHistMatches += 1
			Next
			$fMatchOverall += $iHistMatches / $iSize * 100
		Next
		if $iSCIndex_Main/4 > $iSCThresh Then
;~ 			ConsoleWrite("Unicolor Warning: " & $iSCIndex_Main/4 & " in File " & $sFileMain & @CRLF)
			FileWriteLine($hLogFile, "Unicolor Warning: " & $iSCIndex_Main/4 & " in Collection File " & $sFileMain )
			ContinueLoop(2)
		EndIf

		$fMatchOverall /= 4

		If $fMatchOverall > $iMatchThreshold Then
			If $iInteractive Then
				GUICtrlSetData($hLabel, "match found " & Int($fMatchOverall) & "%")
				$bWait = True
				While $bWait
					Sleep(100)
				WEnd
				GUICtrlSetData($hLabel, "")
			EndIf
			FileWriteLine($hLogFile, $sFileNameMain & " -> " & $sFileNameComp & " : " & Int($fMatchOverall) & "%")
			If $iKillThresh And Int($fMatchOverall) >= $iKillThresh Then
				FileWriteLine($hLogFile, "Deleting: " & StringReplace(StringTrimRight($sFileNameComp, 4), "_", ".", -1) & " : " & FileDelete($sPath2 & "\" & StringReplace(StringTrimRight($sFileNameComp, 4), "_", ".", -1)))
			EndIf
			FileWriteLine($hLogFile, "----------------------------------------------------" & @CRLF)
		EndIf
		_GDIPlus_ImageDispose($hCompImage)
		_GDIPlus_BitmapDispose($hThumbComp)
		$iHandleCounter += 1

	Next

	If $bSingleDir Then
		$iLoopTime = (TimerDiff($Timer) / $aCollectionFiles[0]) * (($aCollectionFiles[0] * ($aCollectionFiles[0] + 1)) / 2)
	Else
		$iLoopTime = $aCollectionFiles[0] * TimerDiff($Timer)
	EndIf

	$aCollectionFiles[0] -= 1

	$iRunningTime = $iLoopTime / 1000
	_GUICtrlStatusBar_SetText($hStatus, "Estimated: " & Int($iRunningTime / 3600) & " h " & Int($iRunningTime / 60) - (Int($iRunningTime / 3600) * 60) & " m " & Int($iRunningTime) - Int($iRunningTime / 60) * 60 & " s")
	_GDIPlus_ImageDispose($hMainImage)
	_GDIPlus_BitmapDispose($hThumbMain)
Next
_Exit()

Func _ThumbNailer($sSource, $sDest)

	Local $aSourceFiles = _FileListToArrayRec($sSource, "*", 1, 1, 0, 2), $sFile = "", $sDestFile, $sCommandLine = "", $sStatus = _GUICtrlStatusBar_GetText($hStatus, 0), $c = 1, $iError

	DirCreate(@ScriptDir & '\' & $sDest)
	FileWriteLine($hLogFile, $sStatus)
	For $sFile In $aSourceFiles
		If IsInt($sFile) Then ContinueLoop
		_GUICtrlStatusBar_SetText($hStatus, $sStatus & " " & $c & "/" & UBound($aSourceFiles) - 1)
		$sDestFile = _StringExplode($sFile, "\")
		$sDestFile = $sDestFile[UBound($sDestFile) - 1]
		$sDestFile = StringReplace($sDestFile, ".", "_") & ".jpg"
		$sCommandLine = @ScriptDir & '\mtn\ffmpeg -i "' & $sFile & '" -ss 5 -vf thumbnail -frames:v 1 "' & @ScriptDir & '\' & $sDest & '\' & $sDestFile & '"'
		$iError = RunWait($sCommandLine, @ScriptDir, @SW_HIDE)
		If $iError Then
			FileWriteLine($hLogFile, "Failed: " & $sFile)
		Else
			_CheckBlack()
		EndIf
		$c += 1
	Next
	_GUICtrlStatusBar_SetText($hStatus, "")
	FileWriteLine($hLogFile, "-------------------------------------")

EndFunc   ;==>_ThumbNailer

Func _CheckBlack()
	Return
EndFunc   ;==>_CheckBlack

Func _Redraw()

	_GDIPlus_GraphicsDrawImage($hGraphics, $hThumbMain, 10, 10)
	If $bWait Then _GDIPlus_GraphicsDrawImage($hGraphics, $hThumbComp, 150, 10)

EndFunc   ;==>_Redraw

Func _Exit()
	_GDIPlus_ImageDispose($hCompImage)
	_GDIPlus_ImageDispose($hMainImage)
	For $handle In $aFTCHandles
		_GDIPlus_ImageDispose($handle)
	Next
	_GDIPlus_GraphicsDispose($hGraphics)
	_GDIPlus_Shutdown()
	GUIDelete($hGui)
	FileClose($hLogFile)
	DirRemove(@ScriptDir & "\temp1", 1)
	If Not $bSingleDir Then DirRemove(@ScriptDir & "\temp2", 1)
	Exit
EndFunc   ;==>_Exit

Func _Thumb($hImage)
	Return _GDIPlus_ImageResize($hImage, 120, 80)
EndFunc   ;==>_Thumb

Func _Continue()
	$bWait = False
EndFunc   ;==>_Continue

