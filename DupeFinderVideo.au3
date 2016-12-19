#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_UseX64=y
#Tidy_Parameters=/reel
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
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
#include <StringConstants.au3>
#include <EditConstants.au3>

AutoItSetOption("MustDeclareVars", 1)
AutoItSetOption("GUIOnEventMode", 1)

#Region Variable Defs
Global $sPath1, $sPath2, $aCollectionFiles[1][3], $aFilesToCompare[1][3], $bSingleDir = 0, $iInnerStart = 1
Global $Timer, $iRunningTime, $iLoopTime, $iTimePerPicture, $iTimerVar
Global $hMainImage, $hCompImage
Global $iSize, $iHistMatches = 0, $fMatchOverall = 0, $iSCIndex_Main = 0, $iBlackness

Global $aHistogramFormat[] = [$GDIP_HistogramFormatGray, $GDIP_HistogramFormatR, $GDIP_HistogramFormatG, $GDIP_HistogramFormatB]
Global $tChannel_Main, $tChannel_Comp
Global $hThumbMain, $hThumbComp
Global $sFileNameMain, $sFileNameComp
#EndRegion Variable Defs

#Region gui variables
Global $hGui, $hStatus, $hEdit
#EndRegion gui variables

#Region parameter defs
Global $sDividerLine = "----------------------------------------------------" ;
Global $hLogFile = FileOpen(@ScriptDir & "\" & @YEAR & @MON & @MDAY & "_" & @HOUR & "-" & @MIN & "_dupefinder.log", 32 + 2)
Global $aCompSize[4][2] = [[160, 120], [320, 240], [480, 360], [640, 480]]
Global $iSearchRange_ms = 5000
Global $iSens = 150, $iMatchThreshold = 80, $iCompSize = 2, $iKillThresh = 100, $iSCThresh = 180, $iBlacknessThresh = 6
Global $sFileFilter = "*.avi;*.mp4;*.wmv;*.flv;*.divx;*.mkv;*.mov;*.mpg;*.mpeg;*.webm;*.ts;*.mts;*.3gp"
#EndRegion parameter defs

If Not _GDIPlus_Startup() Then
	MsgBox($MB_SYSTEMMODAL, "ERROR", "GDIPlus.dll v1.1 not available")
	Exit
EndIf

#Region Gui
$hGui = GUICreate("DupeFinder", 600, 400)
$hStatus = _GUICtrlStatusBar_Create($hGui, -1, "")
GUISetOnEvent($GUI_EVENT_CLOSE, "_Exit")
$hEdit = GUICtrlCreateEdit("", 6, 6, 585, 355, $ES_READONLY + $ES_AUTOVSCROLL)

GUISetState(@SW_SHOW)
#EndRegion Gui

$sPath1 = FileSelectFolder("select collection folder", "", 1, "F:\DupeTest\borders", $hGui)
If @error Then _Exit()

$sPath2 = FileSelectFolder("select a folder to compare", "", 1, $sPath1, $hGui)
If @error Then _Exit()

_GUICtrlStatusBar_SetText($hStatus, "Creating Collection Thumbnails")

_ThumbNailer($sPath1, $aCollectionFiles)
For $i = 1 To UBound($aCollectionFiles) - 1
	$aCollectionFiles[$i][2] = Number($aCollectionFiles[$i][2])
Next
_ArraySort($aCollectionFiles, 0, 1, 0, 2)

If $sPath1 == $sPath2 Then
	$bSingleDir = 1
	$aFilesToCompare = $aCollectionFiles
Else
	_GUICtrlStatusBar_SetText($hStatus, "Creating Compare Thumbnails")
	_ThumbNailer($sPath2, $aFilesToCompare)
	For $i = 1 To UBound($aFilesToCompare) - 1
		$aFilesToCompare[$i][2] = Number($aFilesToCompare[$i][2])
	Next
	_ArraySort($aFilesToCompare, 0, 1, 0, 2)
EndIf

_GUICtrlStatusBar_SetText($hStatus, "")

$iTimerVar = $aCollectionFiles[0][0]

For $iOuterLoop = 1 To $aCollectionFiles[0][0] - $bSingleDir
;~ 	Generate working values

	$sFileNameMain = _FileName($aCollectionFiles[$iOuterLoop][0])

	$hMainImage = _GDIPlus_ImageResize($aCollectionFiles[$iOuterLoop][1], $aCompSize[$iCompSize][0], $aCompSize[$iCompSize][1])

	$Timer = TimerInit()
	If $bSingleDir Then
		$iInnerStart = $iOuterLoop + 1
	EndIf
	For $iInnerLoop = $iInnerStart To $aFilesToCompare[0][0]

		If (Abs($aCollectionFiles[$iOuterLoop][2] - $aFilesToCompare[$iInnerLoop][2]) < $iSearchRange_ms) Or $iSearchRange_ms = -1 Then

			$sFileNameComp = _FileName($aFilesToCompare[$iInnerLoop][0])
			$hCompImage = _GDIPlus_ImageResize($aFilesToCompare[$iInnerLoop][1], $aCompSize[$iCompSize][0], $aCompSize[$iCompSize][1])

			; Compare Channels
			$fMatchOverall = 0
			$iSCIndex_Main = 0
			For $Format In $aHistogramFormat
				$iSize = _GDIPlus_BitmapGetHistogramSize($Format)
				$tChannel_Main = DllStructCreate("uint[" & $iSize & "];")
				_GDIPlus_BitmapGetHistogram($hMainImage, $Format, $iSize, $tChannel_Main)
				$tChannel_Comp = DllStructCreate("uint[" & $iSize & "];")
				_GDIPlus_BitmapGetHistogram($hCompImage, $Format, $iSize, $tChannel_Comp)
				$iHistMatches = 0
				For $i = 1 To $iSize
					If Abs(DllStructGetData($tChannel_Main, 1, $i) - DllStructGetData($tChannel_Comp, 1, $i)) < $iSens Then $iHistMatches += 1
				Next
				$fMatchOverall += $iHistMatches / ($iSize) * 100
			Next

			$fMatchOverall /= 4
			If $fMatchOverall > $iMatchThreshold Then
				_Log($sFileNameMain & " -> " & $sFileNameComp & " : " & Int($fMatchOverall) & "%")
				If $iKillThresh And Int($fMatchOverall) >= $iKillThresh Then
;~ 				_Log("Deleting: " & StringReplace(StringTrimRight($sFileNameComp, 4), "_", ".", -1) & " : " & FileDelete($sPath2 & "\" & StringReplace(StringTrimRight($sFileNameComp, 4), "_", ".", -1)))
				EndIf
				_Log($sDividerLine)
			EndIf
			_GDIPlus_ImageDispose($hCompImage)
		EndIf
	Next

	If $bSingleDir Then
		$iLoopTime = (TimerDiff($Timer) / $iTimerVar) * (($iTimerVar * ($iTimerVar + 1)) / 2)
	Else
		$iLoopTime = $iTimerVar * TimerDiff($Timer)
	EndIf
	$iTimerVar -= 1

	$iRunningTime = $iLoopTime / 1000
	_GUICtrlStatusBar_SetText($hStatus, "Estimated: " & Int($iRunningTime / 3600) & " h " & Int($iRunningTime / 60) - (Int($iRunningTime / 3600) * 60) & " m " & Int($iRunningTime) - Int($iRunningTime / 60) * 60 & " s")
	_GDIPlus_ImageDispose($hMainImage)
	_GDIPlus_BitmapDispose($hThumbMain)
Next

_Exit()

Func _ThumbNailer($sSource, ByRef $aArray)

	Local $aSourceFiles = _FileListToArrayRec($sSource, $sFileFilter, 1, 1, 0, 2), $bData
	Local $sStatus = _GUICtrlStatusBar_GetText($hStatus, 0)
	Local $bThumbOK = True, $sCropString = "", $iCropCount = 0

	_Log($sStatus)
	_Log($aSourceFiles[0] & " files found")
	For $i = 1 To $aSourceFiles[0]
		_GUICtrlStatusBar_SetText($hStatus, $i & "/" & $aSourceFiles[0] & " : " & _FileName($aSourceFiles[$i]))
		$sCropString = ""
		$iCropCount = 0
		Do
			$bThumbOK = True
			$bData = _Thumbnail_Binary($aSourceFiles[$i], $sCropString)
			If @error Then
				_Log("failed: " & $aSourceFiles[$i])
				_Log($bData)
				ContinueLoop
			Else
				Switch $iCropCount
					Case 0,1
						$sCropString = _BorderCrop($bData, $aSourceFiles[$i])	; test on borders
					Case 2,3
						$sCropString = _BorderCrop($bData, $aSourceFiles[$i], False) ; crop top & bottom
					Case Else
						_Log("border detection failed: " & $aSourceFiles[$i])
						ContinueLoop
				EndSwitch
				If $sCropString <> "" Then
					$iCropCount += 1
					$bThumbOK = False
				Else
					_ArrayAdd($aArray, $aSourceFiles[$i] & "|" & _GDIPlus_BitmapCreateFromMemory($bData) & "|" & _MediaInfo($aSourceFiles[$i], "duration"))
				EndIf
			EndIf
		Until $bThumbOK
	Next
	$aArray[0][0] = UBound($aArray) - 1
	_GUICtrlStatusBar_SetText($hStatus, "")
	_Log($aArray[0][0] & " thumbnails created")
	_Log($sDividerLine)

EndFunc   ;==>_ThumbNailer

Func _Thumbnail_Binary($sFileName, $sCropString = "")

	Local $iPID, $bData, $sError

	$iPID = Run('ffmpeg -hide_banner -i "' & $sFileName & '" -vf "fps=fps=1/3,' & $sCropString & 'scale=150:-1,tile=3x3,format=pix_fmts=yuv420p" -frames:v 1 -vsync 0 -f mjpeg -', @ScriptDir, @SW_HIDE, BitOR($STDOUT_CHILD, $STDERR_CHILD))
	ProcessWaitClose($iPID)
	If @extended = 0 Then
		$bData = StdoutRead($iPID, False, True)
		$sError = StderrRead($iPID)
		ConsoleWrite($sError & @CRLF)
		Return $bData
	Else
		$sError = StderrRead($iPID)
		ConsoleWrite($sError & @CRLF)
		SetError(1)
		Return $sError
	EndIf

EndFunc   ;==>_Thumbnail_Binary

Func _BorderCrop($bThumbData, $sFile, $LeftRight = True)

	Local $iBlackness = 0, $fFactor, $iNewWidth, $iNewHeight, $aMediaDim, $_Return = ""
	Local $iBlackness_First = 0, $iBlackness_Last = 0

	Local $hImage = _GDIPlus_BitmapCreateFromMemory($bThumbData)

	Local $iWidth = _GDIPlus_ImageGetWidth($hImage)
	Local $iHeight = _GDIPlus_ImageGetHeight($hImage)
	Local $iPixelcount = $iWidth * $iHeight
	Local $iSize = _GDIPlus_BitmapGetHistogramSize($GDIP_HistogramFormatGray)
	Local $tChannel = DllStructCreate("uint[" & $iSize & "];")
	_GDIPlus_BitmapGetHistogram($hImage, $GDIP_HistogramFormatGray, $iSize, $tChannel)

	Local $hFirst = _GDIPlus_BitmapCloneArea($hImage, 0, 0, $iWidth / 3, $iHeight / 3)
	Local $tChannel_First = DllStructCreate("uint[" & $iSize & "];")
	_GDIPlus_BitmapGetHistogram($hFirst, $GDIP_HistogramFormatGray, $iSize, $tChannel_First)

	Local $hLast = _GDIPlus_BitmapCloneArea($hImage, 2 * ($iWidth / 3), 2 * ($iHeight / 3), $iWidth / 3, $iHeight / 3)
	Local $tChannel_Last = DllStructCreate("uint[" & $iSize & "];")
	_GDIPlus_BitmapGetHistogram($hLast, $GDIP_HistogramFormatGray, $iSize, $tChannel_Last)

	For $i = 1 To $iBlacknessThresh
		$iBlackness += DllStructGetData($tChannel, 1, $i)
		$iBlackness_First += DllStructGetData($tChannel_First, 1, $i)
		$iBlackness_Last += DllStructGetData($tChannel_Last, 1, $i)
		If $i = 2 And $iBlackness < 0.48 Then Return ""
	Next

	If Abs(($iBlackness / $iPixelcount) - ($iBlackness_First / ($iPixelcount / 9))) > 0.01 Then Return ""
	If Abs(($iBlackness / $iPixelcount) - ($iBlackness_Last / ($iPixelcount / 9))) > 0.01 Then Return ""

	If $iBlackness / $iPixelcount > 0.8 Then
		_Log(_FileName($sFile) & " is too dark -> compare will produce false positives")
	ElseIf $iBlackness / $iPixelcount > 0.5 Then
		$fFactor = 1 - ($iBlackness / $iPixelcount)
		$aMediaDim = _MediaInfo($sFile, "width|height")
		If $LeftRight Then
;~ 			_Log(_FileName($sFile) & " black border detected -> cropping left/right")
			$iNewWidth = Round((($aMediaDim[0] * $aMediaDim[1]) * $fFactor) / $aMediaDim[1])
			While Mod($iNewWidth, 4)
				$iNewWidth -= 1
			WEnd
			$iNewWidth -= 4 ;Tweaking output width
			$_Return = "crop=w=" & $iNewWidth & ":h=" & $aMediaDim[1] & ":x=" & ($aMediaDim[0] - $iNewWidth) / 2 & ":y=0,"
		Else
;~ 			_Log(_FileName($sFile) & " black border detected -> cropping top/bottom")
			$iNewHeight = Round((($aMediaDim[0] * $aMediaDim[1]) * $fFactor) / $aMediaDim[0])
			While Mod($iNewHeight, 4)
				$iNewHeight -= 1
			WEnd
			$iNewHeight -= 4 ;Tweaking output height
			$_Return = "crop=w=" & $aMediaDim[0] & ":h=" & $iNewHeight & ":x=0:y=" & ($aMediaDim[1] - $iNewHeight) / 2 & ","
		EndIf

	EndIf

	$tChannel = 0
	$tChannel_First = 0
	$tChannel_Last = 0
	_GDIPlus_ImageDispose($hImage)
	_GDIPlus_ImageDispose($hFirst)
	_GDIPlus_ImageDispose($hLast)
;~ 	_Log($_Return)
	Return $_Return

EndFunc   ;==>_BorderCrop

Func _MediaInfo($_file, $Request = Default)

	Local $__MediaInfo, $__MediaInfoHandle
	Local $_Inform, $_Return, $_Attributes, $_Result[] = [""]

	If @AutoItX64 Then
		$__MediaInfo = DllOpen("MediaInfo64.dll")
	Else
		$__MediaInfo = DllOpen("MediaInfo.dll")
	EndIf

	$__MediaInfoHandle = DllCall($__MediaInfo, "ptr", "MediaInfo_New")
	DllCall($__MediaInfo, "int", "MediaInfo_Open", "ptr", $__MediaInfoHandle[0], "wstr", $_file)
	DllCall($__MediaInfo, "wstr", "MediaInfo_Option", "ptr", 0, "wstr", "Complete", "wstr", "1")
	$_Inform = DllCall($__MediaInfo, "wstr", "MediaInfo_Inform", "ptr", $__MediaInfoHandle[0], "int", 0)
	DllCall($__MediaInfo, "int", "MediaInfo_Close", "ptr", $__MediaInfoHandle[0])
	DllCall($__MediaInfo, "none", "MediaInfo_Delete", "ptr", $__MediaInfoHandle[0])
	DllClose($__MediaInfo)

	$_Return = StringSplit($_Inform[0], @LF)
	If @error Then
		SetError(1, 0, "")
		Return
	EndIf

	$_Attributes = StringSplit($Request, "|", $STR_NOCOUNT)
	If @error Then
		If $_Attributes[0] = Default Then
			Return $_Return
		Else
			For $String In $_Return
				If StringInStr($String, $_Attributes[0]) Then
					Local $aDummy = StringSplit($String, ": ", 1)
					Return $aDummy[2]
				EndIf
			Next
		EndIf
	Else
		For $Attribute In $_Attributes
			For $String In $_Return
				If StringInStr($String, $Attribute) Then
					Local $aDummy = StringSplit($String, ": ", 1)
					_ArrayAdd($_Result, $aDummy[2])
					ExitLoop
				EndIf
			Next
		Next
		_ArrayDelete($_Result, 0)
		Return $_Result
	EndIf

EndFunc   ;==>_MediaInfo

Func _FileName($sString)
	Local $aFileName = _StringExplode($sString, "\")
	Return $aFileName[UBound($aFileName) - 1]
EndFunc   ;==>_FileName

Func _Log($sMessage)

	FileWriteLine($hLogFile, $sMessage)
	ConsoleWrite($sMessage & @CRLF)
	GUICtrlSetData($hEdit, $sMessage & @CRLF, " ")

EndFunc   ;==>_Log

Func _Exit()
	_GDIPlus_ImageDispose($hCompImage)
	_GDIPlus_ImageDispose($hMainImage)
	For $i = 1 To $aCollectionFiles[0][0]
		_GDIPlus_ImageDispose($aCollectionFiles[$i][1])
	Next
	For $i = 1 To $aFilesToCompare[0][0]
		_GDIPlus_ImageDispose($aFilesToCompare[$i][1])
	Next
	_GDIPlus_Shutdown()
	MsgBox(0, "", "Done")
	GUIDelete($hGui)
	FileClose($hLogFile)
	Exit
EndFunc   ;==>_Exit

