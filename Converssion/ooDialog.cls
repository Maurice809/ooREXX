/*----------------------------------------------------------------------------*/
/*                                                                            */
/* Copyright (c) 1995, 2004 IBM Corporation. All rights reserved.             */
/* Copyright (c) 2005-2014 Rexx Language Association. All rights reserved.    */
/*                                                                            */
/* This program and the accompanying materials are made available under       */
/* the terms of the Common Public License v1.0 which accompanies this         */
/* distribution. A copy is also available at the following address:           */
/* https://www.oorexx.org/license.html                                        */
/*                                                                            */
/* Redistribution and use in source and binary forms, with or                 */
/* without modification, are permitted provided that the following            */
/* conditions are met:                                                        */
/*                                                                            */
/* Redistributions of source code must retain the above copyright             */
/* notice, this list of conditions and the following disclaimer.              */
/* Redistributions in binary form must reproduce the above copyright          */
/* notice, this list of conditions and the following disclaimer in            */
/* the documentation and/or other materials provided with the distribution.   */
/*                                                                            */
/* Neither the name of Rexx Language Association nor the names                */
/* of its contributors may be used to endorse or promote products             */
/* derived from this software without specific prior written permission.      */
/*                                                                            */
/* THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS        */
/* "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT          */
/* LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS          */
/* FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT   */
/* OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,      */
/* SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED   */
/* TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA,        */
/* OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY     */
/* OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING    */
/* NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS         */
/* SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.               */
/*                                                                            */
/*----------------------------------------------------------------------------*/

::requires 'ooShapes.cls'
::requires 'oodialog' LIBRARY


/**
 * Windows Dialog Interface for Open Object Rexx (ooRexx.)
 *
 * Utility Classes, "short-cut" dialogs and routines, public routines, and
 * utility dialogs.
 *
 * The mechanism for putting the .ApplicationManager object in the .local
 * environment relies on maintaining the first class definitions in this file as
 * being: .ResourceUtils, .ApplicationManager, and then .DlgUtils.
 *
 * Note:  This "class" file can not be used by itself, as for instance
 *        UserDialog.cls could.  It is intended to be merged into the main
 *        ooDialog framework file as the first file.  It contains classes that
 *        subclass other classes that will be present in the single framework
 *        file, but are not present in this file.
 */


::class 'ResourceUtils' public mixinclass object

-- Directory object containing symbolic constants
::attribute constDir get
::attribute constDir set private
::attribute processingLoad private    -- in loadItems ?

::method checkfile private
   use arg f
   if (f~lines = 0) then do
      f~close
      self~processingLoad = 0
      ret = errorDialog("Error reading resource file!" f)
      return 1
   end
   return 0

::method checkID external "LIBRARY oodialog rsrcUtils_checkID"
::method errorfile private
   use arg f, s
   f~close
   self~processingLoad = 0
   ret = errorDialog("Error reading resource file:" f "("s")")

-- This method is very specific looking only for an ICON resource statement.
::method findIconInRcFile private
    use strict arg resFile, iconID

    if \ SysIsFile(resFile) then do
        foundFile = SysSearchPath("PATH", resFile)
        if foundFile == "" then do
            msg = 'Unable to find resource script file "'resFile'"'
            j = MessageDialog(msg, 0, "File Not Found Error", "OK", "WARNING", "SYSTEMMODAL")
            return ""
        end
        resFile = foundFile
    end

    f = .stream~new(resFile)
    ret = f~open(read)
    if ret \= "READY:" then do
        msg = 'Resource script file "'resFile'" is not readable:' ret
        j = MessageDialog(msg, 0, "File Open Error", "OK", "WARNING", "SYSTEMMODAL")
        return ""
    end

    found = .false; iconFile = ''
    fl = f~lines
    do while \ found
        do while iconFile == '' & fl > 0
            s = f~linein; fl -= 1
            if s~wordpos("ICON") = 2 then do
                -- ICON RESOURCE statement as opposed to an ICON CONTROL statement.
                -- filename could have spaces and *should* be in quotes.
                parse var s nameID ic fileName
                if nameID~translate == iconID~translate then do
                    found = .true
                    iconfile = fileName~strip
                end
            end
        end
        if fl < 1 then leave
    end

    f~close

    -- The file name in the resource script file will be in a C string format.
    -- We need to change any escaped slashes.  In addition, the file name will
    -- most likely be used in LoadImage() and must not be enclosed in quotes.
    if iconFile~pos("\\") <> 0 then iconFile = iconFile~changestr("\\", '\')
    iconFile = iconFile~strip('B', '"')

    if iconFile == '' then do
        msg = 'Resource script file "'resFile'" does not contain an ICON resource statement for ID:' iconID
        j = MessageDialog(msg, 0, "Resource Script File Error", "OK", "WARNING", "SYSTEMMODAL")
    end
    return iconFile

::method getResourceID unguarded external "LIBRARY oodialog rsrcUtils_resolveResourceID"
::method idError private external "LIBRARY oodialog rsrcUtils_idError"
::method parseIncludeFile
  use strict arg hFile

  if \ SysIsFile(hFile) then do
    foundFile = SysSearchPath("PATH", hFile)
    if foundFile == "" then do
      msg = 'Unable to find header file "'hFile'"'
      j = MessageDialog(msg, 0, "File Not Found Error", "OK", "WARNING", "SYSTEMMODAL")
      return .false
    end
    hFile = foundFile
  end

  f = .stream~new(hFile)
  ret = f~open(read)
  if ret \= "READY:" then do
    msg = 'Header file "'hFile'" is not readable:' ret
    j = MessageDialog(msg, 0, "File Open Error", "OK", "WARNING", "SYSTEMMODAL")
    return .false
  end

  global = (self~isA(.ApplicationManager) | .constDirUsage == 'use only')

  do while f~state == "READY"
    line = f~linein~strip('L')

    if line~abbrev("#ifdef") then do
      self~skipThroughIfDefs(f, line)
      iterate
    end

    if line~abbrev("#define") & line~words == 3 then do
      parse var line def symbol numericID .
      if numericID~datatype('W') then do
        if global then .constDir[symbol] = numericID
        else self~constDir[symbol~translate] = numericID
      end
    end
  end
  f~close
  return .true

::method resolveIconID private external "LIBRARY oodialog rsrcUtils_resolveIconID_pvt"
::method resolveSymbolicId unguarded external "LIBRARY oodialog rsrcUtils_resolveResourceID"
::method skipThroughIfDefs private
  use arg fObj, line

  if \ line~abbrev("#ifdef") & \ line~abbrev("#ifndef") then return
  ifDefStack = .queue~new
  ifDefStack~push(line)
  do while fObj~state == "READY"
    l = fObj~linein~strip("L")
    select
      when l~abbrev("#endif") then ifDefStack~pull
      when l~abbrev("#ifdef") then ifDefStack~push(l)
      when l~abbrev("#ifndef") then ifDefStack~push(l)
      otherwise nop
    end
    if ifDefStack~items == 0 then leave
  end


/**
 * Return the symbolic ID from the ConstDir that matches the numeric ID.
 * The docs will advise users of ooDialog to use unique numbers for all
 * resources.
 */
::method resolveNumericID unguarded
  use strict arg numericID
  if \ numericID~datatype('W') then return -1

  if self~isA(.ApplicationManager) | .constDirUsage == "use only" then do
    symbol = .constDir~index(numericID)
  end
  else do
    if .constDirUsage == "use first" then do
      symbol = .constDir~index(numericID)
      if symbol == .nil then symbol = self~constDir~index(numericID)
    end
    else if .constDirUsage == "use last" then do
      symbol = self~constDir~index(numericID)
      if symbol == .nil then symbol = .constDir~index(numericID)
    end
    else do
      symbol = self~constDir~index(numericID)
    end
  end

  if symbol == .nil then return -1
  else return symbol


::class 'ApplicationManager' public inherit ResourceUtils

::attribute srcDir get external "LIBRARY oodialog app_srcDir_atr"

::method init external "LIBRARY oodialog app_init"

::method addToConstDir external "LIBRARY oodialog app_addToConstDir"
::method autoDetection external "LIBRARY oodialog app_autoDetection"
::method defaultFont external "LIBRARY oodialog app_defaultFont"
::method defaultIcon external "LIBRARY oodialog app_defaultIcon"
::method initAutoDetection external "LIBRARY oodialog app_initAutoDetection"  -- Internal use only.
::method requiredOS external "LIBRARY oodialog app_requiredOS"
::method setDefaults external "LIBRARY oodialog app_setDefaults"
::method useGlobalConstDir external "LIBRARY oodialog app_useGlobalConstDir"

::class 'DlgUtil' public
::method init class external "LIBRARY oodialog dlgutil_init_cls"
::method and class external "LIBRARY oodialog dlgutil_and_cls"
::method comctl32Version class external "LIBRARY oodialog dlgutil_comctl32Version_cls"
::method errMsg class external "LIBRARY oodialog dlgutil_errMsg_cls"
::method getGUID class external "LIBRARY oodialog dlgutil_getGuid_cls"
::method getSystemMetrics class external "LIBRARY oodialog dlgutil_getSystemMetrics_cls"
::method halt class external "LIBRARY oodialog dlgutil_halt_cls"
::method handleToPointer class external "LIBRARY oodialog dlgutil_handleToPointer_cls"
::method hiWord class external "LIBRARY oodialog dlgutil_hiWord_cls"
::method loWord class external "LIBRARY oodialog dlgutil_loWord_cls"
::method makeLParam class external "LIBRARY oodialog dlgutil_makeLPARAM_cls"
::method makeWParam class external "LIBRARY oodialog dlgutil_makeWPARAM_cls"
::method or class external "LIBRARY oodialog dlgutil_or_cls"
::method screenArea class external "LIBRARY oodialog dlgutil_screenArea_cls"
::method screenSize class external "LIBRARY oodialog dlgutil_screenSize_cls"
::method shiftLeft class external "LIBRARY oodialog dlgutil_shiftLeft_cls"
::method shiftRight class external "LIBRARY oodialog dlgutil_shiftRight_cls"
::method sHiWord class external "LIBRARY oodialog dlgutil_shiWord_cls"
::method signed class external "LIBRARY oodialog dlgutil_signed_cls"
::method signed32 class external "LIBRARY oodialog dlgutil_signed32_cls"
::method sLoWord class external "LIBRARY oodialog dlgutil_sloWord_cls"
::method sShiftLeft class external "LIBRARY oodialog dlgutil_sShiftLeft_cls"
::method sShiftRight class external "LIBRARY oodialog dlgutil_sShiftRight_cls"
::method terminate class external "LIBRARY oodialog dlgutil_terminate_cls"
::method threadID class external "LIBRARY oodialog dlgutil_threadID_cls"
::method unsigned class external "LIBRARY oodialog dlgutil_unsigned_cls"
::method unsigned32 class external "LIBRARY oodialog dlgutil_unsigned32_cls"
::method version class external "LIBRARY oodialog dlgutil_version_cls"
::method windowFromPoint class external "LIBRARY oodialog dlgutil_windowFromPoint_cls"

::method test class external "LIBRARY oodialog dlgutil_test_cls"

::class 'SPI' public
::constant WHEEL_PAGESCROLL   4294267295
::method init class external "LIBRARY oodialog spi_init_cls"

::attribute dragHeight get class external "LIBRARY oodialog spi_getDragHeight_cls"
::attribute dragHeight set class external "LIBRARY oodialog spi_setDragHeight_cls"
::attribute dragWidth get class external "LIBRARY oodialog spi_getDragWidth_cls"
::attribute dragWidth set class external "LIBRARY oodialog spi_setDragWidth_cls"
::attribute menuAnimation get class external "LIBRARY oodialog spi_getMenuAnimation_cls"
::attribute menuAnimation set class external "LIBRARY oodialog spi_setMenuAnimation_cls"
::attribute menuFade get class external "LIBRARY oodialog spi_getMenuFade_cls"
::attribute menuFade set class external "LIBRARY oodialog spi_setMenuFade_cls"
::attribute mouseHoverHeight get class external "LIBRARY oodialog spi_getMouseHoverHeight_cls"
::attribute mouseHoverHeight set class external "LIBRARY oodialog spi_getMouseHoverHeight_cls"
::attribute mouseHoverTime get class external "LIBRARY oodialog spi_getMouseHoverTime_cls"
::attribute mouseHoverTime set class external "LIBRARY oodialog spi_getMouseHoverTime_cls"
::attribute mouseHoverWidth get class external "LIBRARY oodialog spi_getMouseHoverWidth_cls"
::attribute mouseHoverWidth set class external "LIBRARY oodialog spi_getMouseHoverWidth_cls"
::attribute nonClientMetrics get class external "LIBRARY oodialog spi_getNonClientMetrics_cls"  -- For 4.2.2
::attribute nonClientMetrics set class external "LIBRARY oodialog spi_setNonClientMetrics_cls"  -- For 4.2.2

::attribute updateFlag get class external "LIBRARY oodialog spi_getUpdateFlag_cls"
::attribute updateFlag set class external "LIBRARY oodialog spi_setUpdateFlag_cls"

::attribute wheelScrollLines get class external "LIBRARY oodialog spi_getWheelScrollLines_cls"
::attribute wheelScrollLines set class external "LIBRARY oodialog spi_setWheelScrollLines_cls"
::attribute workArea get class external "LIBRARY oodialog spi_getWorkArea_cls"
::attribute workArea set class external "LIBRARY oodialog spi_setWorkArea_cls"

::class 'SM' public
::attribute cMouseButtons get class external "LIBRARY oodialog sm_cMouseButtons_cls"
::attribute cxCursor get class external      "LIBRARY oodialog sm_cxCursor_cls"
::attribute cxDrag get class external        "LIBRARY oodialog sm_cxDrag_cls"
::attribute cxFixedFrame get class external  "LIBRARY oodialog sm_cxFixedFrame_cls"
::attribute cxIcon get class external        "LIBRARY oodialog sm_cxIcon_cls"
::attribute cxScreen get class external      "LIBRARY oodialog sm_cxScreen_cls"
::attribute cxSize get class external        "LIBRARY oodialog sm_cxSize_cls"
::attribute cxSmIcon get class external      "LIBRARY oodialog sm_cxSmIcon_cls"
::attribute cxVscroll get class external     "LIBRARY oodialog sm_cxVScroll_cls"
::attribute cyCaption get class external     "LIBRARY oodialog sm_cyCaption_cls"
::attribute cyCursor get class external      "LIBRARY oodialog sm_cyCursor_cls"
::attribute cyDrag get class external        "LIBRARY oodialog sm_cyDrag_cls"
::attribute cyFixedFrame get class external  "LIBRARY oodialog sm_cyFixedFrame_cls"
::attribute cyHscroll get class external     "LIBRARY oodialog sm_cyHScroll_cls"
::attribute cyIcon get class external        "LIBRARY oodialog sm_cyIcon_cls"
::attribute cyMenu get class external        "LIBRARY oodialog sm_cyMenu_cls"
::attribute cyScreen get class external      "LIBRARY oodialog sm_cyScreen_cls"
::attribute cySize get class external        "LIBRARY oodialog sm_cySize_cls"
::attribute cySmIcon get class external      "LIBRARY oodialog sm_cySmIcon_cls"
::attribute menuDropAlignment get class external "LIBRARY oodialog sm_menuDropAlignment_cls"

::class 'OS' public
::method is64bit class external "LIBRARY oodialog os_is64bit"
::method is32on64bit class external "LIBRARY oodialog os_is32on64bit"
::method isWow64 class external "LIBRARY oodialog os_is32on64bit"
::method isW2K class external "LIBRARY oodialog os_isVersion"
::method isXP class external "LIBRARY oodialog os_isVersion"
::method isXP32 class external "LIBRARY oodialog os_isVersion"
::method isXP64 class external "LIBRARY oodialog os_isVersion"
::method isW2K3 class external "LIBRARY oodialog os_isVersion"
::method isVista class external "LIBRARY oodialog os_isVersion"
::method isServer2008 class external "LIBRARY oodialog os_isVersion"
::method isWindows7 class external "LIBRARY oodialog os_isVersion"
::method isServer2008R2 class external "LIBRARY oodialog os_isVersion"
::method isAtLeastW2K class external "LIBRARY oodialog os_isVersion"
::method isAtLeastXP class external "LIBRARY oodialog os_isVersion"
::method isAtLeastW2K3 class external "LIBRARY oodialog os_isVersion"
::method isAtLeastVista class external "LIBRARY oodialog os_isVersion"
::method isAtLeastWindows7 class external "LIBRARY oodialog os_isVersion"
::method settingChanged class external "LIBRARY oodialog os_settingChanged"
::method shellChangeNotify class external "LIBRARY oodialog os_shellChangeNotify"


::class 'Mouse' public
::constant HOVER_DEFAULT           4294967295

::method new class external "LIBRARY oodialog mouse_new_cls"
::method init external "LIBRARY oodialog mouse_init"

::method doubleClickTime class external "LIBRARY oodialog mouse_doubleClickTime_cls"
::method loadCursor class external "LIBRARY oodialog mouse_loadCursor_cls"
::method loadCursorFromFile class external "LIBRARY oodialog mouse_loadCursorFromFile_cls"
::method setDoubleClickTime class external "LIBRARY oodialog mouse_setDoubleClickTime_cls"
::method swapButton class external "LIBRARY oodialog mouse_swapButton_cls"

::method appStarting external "LIBRARY oodialog mouse_setCursor"
::method arrow external "LIBRARY oodialog mouse_setCursor"
::method capture external "LIBRARY oodialog mouse_capture"
::method clipCursor external "LIBRARY oodialog mouse_clipCursor"
::method connectEvent external "LIBRARY oodialog mouse_connectEvent"
::method cross external "LIBRARY oodialog mouse_setCursor"
::method dragDetect external "LIBRARY oodialog mouse_dragDetect"
::method getCapture external "LIBRARY oodialog mouse_get_release_capture"
::method getClipCursor external "LIBRARY oodialog mouse_getClipCursor"
::method getCursorPos external "LIBRARY oodialog mouse_getCursorPos"
::method isButtonDown external "LIBRARY oodialog mouse_isButtonDown"
::method no external "LIBRARY oodialog mouse_setCursor"
::method releaseCapture external "LIBRARY oodialog mouse_get_release_capture"
::method releaseClipCursor external "LIBRARY oodialog mouse_releaseClipCursor"
::method restoreCursor external "LIBRARY oodialog mouse_restoreCursor"
::method setCursor external "LIBRARY oodialog mouse_setCursor"
::method setCursorPos external "LIBRARY oodialog mouse_setCursorPos"
::method showCursor external "LIBRARY oodialog mouse_showCursor"
::method trackEvent external "LIBRARY oodialog mouse_trackEvent"
::method wait external "LIBRARY oodialog mouse_setCursor"

::method test external "LIBRARY oodialog mouse_test"

::class 'Keyboard' public
::method getAsyncKeyState class external "LIBRARY oodialog kb_getAsyncKeyState_cls"

::class 'DayState' public
::method init external "LIBRARY oodialog ds_init"
::method value external "LIBRARY oodialog ds_value"


::class 'DayStates' public

::method makeDayStateBuffer class external "LIBRARY oodialog dss_makeDayStateBuffer"
::method quickDayStateBuffer class external "LIBRARY oodialog dss_quickDayStateBuffer"

::attribute years private

::attribute startMonth get
::attribute startMonth set private

::attribute endMonth get
::attribute endMonth set private

::method init
    expose years startMonth endMonth
    use strict arg year = (.DateTime~today~year - 2), count = 3

    startMonth = .DateTime~fromStandardDate(year || '0101')
    endMonth = .DateTime~fromStandardDate((year + count - 1) || '1201')

    years = .table~new
    do i = year to year + count - 1
        years[i] = self~generateEmptyYear
    end

::method getDayState
    expose startMonth years
    use strict arg dateTime

    year = dateTime~year
    month = dateTime~month

    aYear = years[year]
    if aYear == .nil then return .nil
    else return aYear[month]

::method getDayStateBuffer
    expose startMonth years
    use strict arg dateTime, count

    year = dateTime~year
    month = dateTime~month

    resultArray = .array~new(count)

    aYear = years[year]
    if aYear == .nil then do
        do i = 1 to count
            resultArray[i] = .DayState~new
        end
        return .DayStates~makeDayStateBuffer(resultArray)
    end

    do i = 1 to count
        resultArray[i] = aYear[month]
        month += 1
        if month > 12 then do
            month = 1
            year += 1
            aYear = years[year]
            if aYear == .nil then leave
        end
    end

    if resultArray~items < count then do i = (resultArray~items + 1) to count
        resultArray[i] = .DayState~new
    end

    return .DayStates~makeDayStateBuffer(resultArray)

::method putYear
    expose startMonth endMonth years
    use strict arg dateTime, values

    year = dateTime~year

    newYear = .DateTime~fromStandardDate(year || '0101')
    months = .array~new(12)
    do i = 1 to 12
        if values[i] == .nil then months[i] = .DayState~new
        else months[i] = values[i]
    end

    years[year] = months

    needFill = .false
    if newYear < startMonth then do
        startMonth = newYear
        if years[year + 1] == .nil then needFill = .true
    end
    else if newYear > endMonth then do
        endMonth = .DateTime~fromStandardDate(year || '1201')
        if years[year - 1] == .nil then needFill = .true
    end

    if needFill then self~doFill

::method putMonth
    expose startMonth endMonth years
    use strict arg dateTime, dayState

    year = dateTime~year
    month = dateTime~month

    yearArray = years[year]
    if yearArray == .nil then do
        yearArray = .array~new(12)
        yearArray[month] = dayState
        self~putYear(dateTime, yearArray)
    end
    else do
        yearArray[month] = dayState
    end

::method generateEmptyYear private
    empty = .array~new(12)
    do i = 1 to 12
        empty[i] = .DayState~new
    end
    return empty

::method needFill private
    expose startMonth endMonth years

    do i = startMonth~year to endMonth~year
        if years[i] == .nil then years[i] = self~generateEmptyYear
    end


::class 'VK' mixinclass Object public

-- Virtual Keys, Standard Set.  Note that several of the integer values have
-- duplicate names.
::constant LBUTTON                1
::constant RBUTTON                2
::constant CANCEL                 3
::constant MBUTTON                4
::constant XBUTTON1               5
::constant XBUTTON2               6
                            --    7 : unassigned
::constant BACK                   8
::constant TAB                    9
                            --   10 : reserved
                            --   11 : reserved
::constant CLEAR                 12
::constant RETURN                13
                            --   14 : Microsoft does not list.
                            --   15 : Microsoft does not list.
::constant SHIFT                 16
::constant CONTROL               17
::constant MENU                  18
::constant PAUSE                 19
::constant CAPITAL               20
::constant KANA                  21
::constant HANGEUL               21
::constant HANGUL                21
                            --   22 : Microsoft does not list.
::constant JUNJA                 23
::constant FINAL                 24
::constant HANJA                 25
::constant KANJI                 25
                            --   26 : Microsoft does not list.
::constant ESCAPE                27
::constant CONVERT               28
::constant NONCONVERT            29
::constant ACCEPT                30
::constant MODECHANGE            31
::constant SPACE                 32
::constant PRIOR                 33
::constant NEXT                  34
::constant END                   35
::constant HOME                  36
::constant LEFT                  37
::constant UP                    38
::constant RIGHT                 39
::constant DOWN                  40
::constant SELECT                41
::constant PRINT                 42
::constant EXECUTE               43
::constant SNAPSHOT              44
::constant INSERT                45
::constant DELETE                46
::constant HELP                  47
::constant 0                     48
::constant 1                     49
::constant 2                     50
::constant 3                     51
::constant 4                     52
::constant 5                     53
::constant 6                     54
::constant 7                     55
::constant 8                     56
::constant 9                     57
                            -- 58 - 63 (0x3A -0x3F) Microsoft does not list.
                            -- 0x40 : unassigned
::constant A                     65
::constant B                     66
::constant C                     67
::constant D                     68
::constant E                     69
::constant F                     70
::constant G                     71
::constant H                     72
::constant I                     73
::constant J                     74
::constant K                     75
::constant L                     76
::constant M                     77
::constant N                     78
::constant O                     79
::constant P                     80
::constant Q                     81
::constant R                     82
::constant S                     83
::constant T                     84
::constant U                     85
::constant V                     86
::constant W                     87
::constant X                     88
::constant Y                     89
::constant Z                     90
::constant LWIN                  91
::constant RWIN                  92
::constant APPS                  93
                            -- 0x5E : reserved
::constant SLEEP                 95
::constant NUMPAD0               96
::constant NUMPAD1               97
::constant NUMPAD2               98
::constant NUMPAD3               99
::constant NUMPAD4              100
::constant NUMPAD5              101
::constant NUMPAD6              102
::constant NUMPAD7              103
::constant NUMPAD8              104
::constant NUMPAD9              105
::constant MULTIPLY             106
::constant ADD                  107
::constant SEPARATOR            108
::constant SUBTRACT             109
::constant DECIMAL              110
::constant DIVIDE               111
::constant F1                   112
::constant F2                   113
::constant F3                   114
::constant F4                   115
::constant F5                   116
::constant F6                   117
::constant F7                   118
::constant F8                   119
::constant F9                   120
::constant F10                  121
::constant F11                  122
::constant F12                  123
::constant F13                  124
::constant F14                  125
::constant F15                  126
::constant F16                  127
::constant F17                  128
::constant F18                  129
::constant F19                  130
::constant F20                  131
::constant F21                  132
::constant F22                  133
::constant F23                  134
::constant F24                  135
                            -- 0x88 - 0x8F : unassigned
::constant NUMLOCK              144
::constant SCROLL               145

-- NEC PC-9800 kbd definitions
::constant OEM_NEC_EQUAL        146   -- '=' key on numpad

-- Fujitsu/OASYS kbd definitions
::constant OEM_FJ_JISHO         146   -- 'Dictionary' key
::constant OEM_FJ_MASSHOU       147   -- 'Unregister word' key
::constant OEM_FJ_TOUROKU       148   -- 'Register word' key
::constant OEM_FJ_LOYA          149   -- 'Left OYAYUBI' key
::constant OEM_FJ_ROYA          150   -- 'Right OYAYUBI' key
                            -- 0x97 - 0x9F : unassigned

::constant LSHIFT               160
::constant RSHIFT               161
::constant LCONTROL             162
::constant RCONTROL             163
::constant LMENU                164
::constant RMENU                165
::constant BROWSER_BACK         166
::constant BROWSER_FORWARD      167
::constant BROWSER_REFRESH      168
::constant BROWSER_STOP         169
::constant BROWSER_SEARCH       170
::constant BROWSER_FAVORITES    171
::constant BROWSER_HOME         172
::constant VOLUME_MUTE          173
::constant VOLUME_DOWN          174
::constant VOLUME_UP            174
::constant MEDIA_NEXT_TRACK     176
::constant MEDIA_PREV_TRACK     177
::constant MEDIA_STOP           178
::constant MEDIA_PLAY_PAUSE     179
::constant LAUNCH_MAIL          180
::constant LAUNCH_MEDIA_SELECT  181
::constant LAUNCH_APP1          182
::constant LAUNCH_APP2          183
                            -- 0xB8 - 0xB9 : reserved

::constant OEM_1                186   -- ';:' for US
::constant OEM_PLUS             187   -- '+' any country
::constant OEM_COMMA            188   -- ',' any country
::constant OEM_MINUS            189   -- '-' any country
::constant OEM_PERIOD           190   -- '.' any country
::constant OEM_2                191   -- '/?' for US
::constant OEM_3                192   -- '`~' for US
                            -- 0xC1 - 0xD7 : reserved
                            -- 0xD8 - 0xDA : unassigned

::constant OEM_4                219  --  '[{' for US
::constant OEM_5                220  --  '\|' for US
::constant OEM_6                221  --  ']}' for US
::constant OEM_7                222  --  ''"' for US
::constant OEM_8                223
                            -- 0xE0 : reserved

-- Various ended or enhanced keyboards
::constant OEM_AX               225  --  'AX' key on Japanese AX kbd
::constant OEM_102              226  --  "<>" or "\|" on RT 102-key kbd.
::constant ICO_HELP             227  --  Help key on ICO
::constant ICO_00               228  --  00 key on ICO
::constant PROCESSKEY           229
::constant ICO_CLEAR            230
::constant PACKET               231
                            -- 0xE8 : unassigned

-- Nokia/Ericsson definitions
::constant OEM_RESET            233
::constant OEM_JUMP             234
::constant OEM_PA1              235
::constant OEM_PA2              236
::constant OEM_PA3              237
::constant OEM_WSCTRL           238
::constant OEM_CUSEL            239
::constant OEM_ATTN             240
::constant OEM_FINISH           241
::constant OEM_COPY             242
::constant OEM_AUTO             243
::constant OEM_ENLW             244
::constant OEM_BACKTAB          245
::constant ATTN                 246
::constant CRSEL                247
::constant EXSEL                248
::constant EREOF                249
::constant PLAY                 250
::constant ZOOM                 251
::constant NONAME               252
::constant PA1                  253
::constant OEM_CLEAR            254
                            -- 0xFF : reserved

::method key2name class external "LIBRARY oodialog vk_key2name"
::method key2name       external "LIBRARY oodialog vk_key2name"


::class 'OEM' mixinclass Object public                                                 -- Do not document for 4.2.0

::constant OBM_CLOSE           32754
::constant OBM_UPARROW         32753
::constant OBM_DNARROW         32752
::constant OBM_RGARROW         32751
::constant OBM_LFARROW         32750
::constant OBM_REDUCE          32749
::constant OBM_ZOOM            32748
::constant OBM_RESTORE         32747
::constant OBM_REDUCED         32746
::constant OBM_ZOOMD           32745
::constant OBM_RESTORED        32744
::constant OBM_UPARROWD        32743
::constant OBM_DNARROWD        32742
::constant OBM_RGARROWD        32741
::constant OBM_LFARROWD        32740
::constant OBM_MNARROW         32739
::constant OBM_COMBO           32738
::constant OBM_UPARROWI        32737
::constant OBM_DNARROWI        32736
::constant OBM_RGARROWI        32735
::constant OBM_LFARROWI        32734
::constant OBM_SIZE            32766
::constant OBM_BTSIZE          32761
::constant OBM_CHECK           32760
::constant OBM_CHECKBOXES      32759
::constant OBM_BTNCORNERS      32758

::constant OCR_NORMAL          32512
::constant OCR_IBEAM           32513
::constant OCR_WAIT            32514
::constant OCR_CROSS           32515
::constant OCR_UP              32516
::constant OCR_SIZENWSE        32642
::constant OCR_SIZENESW        32643
::constant OCR_SIZEWE          32644
::constant OCR_SIZENS          32645
::constant OCR_SIZEALL         32646
::constant OCR_NO              32648
::constant OCR_HAND            32649
::constant OCR_APPSTARTING     32650

::constant OIC_SAMPLE          32512
::constant OIC_HAND            32513
::constant OIC_QUES            32514
::constant OIC_BANG            32515
::constant OIC_NOTE            32516
::constant OIC_WINLOGO         32517
::constant OIC_WARNING         32515
::constant OIC_ERROR           32513
::constant OIC_INFORMATION     32516
::constant OIC_SHIELD          32518

::constant IDI_APPLICATION     32512
::constant IDI_HAND            32513
::constant IDI_QUESTION        32514
::constant IDI_EXCLAMATION     32515
::constant IDI_ASTERISK        32516
::constant IDI_WINLOGO         32517
::constant IDI_SHIELD          32518
::constant IDI_WARNING         32515
::constant IDI_ERROR           32513
::constant IDI_INFORMATION     32516


/**
 * Standard Dialog Control Classes.  Some simple short cut dialogs.
 */

-- Create a "default" dialog class and set it to the user dialog.
::class 'Dialog' subclass UserDialog public


-- This class shows a message window for a defined duration
::class 'TimedMessage' subclass UserDialog public

::method init public external "LIBRARY oodialog timedmsg_init"

::method defineDialog
   expose message sx sy
   self~createStaticText(-1, 10, 10, sx+2, sy, , message)

::method initAutoDetection
   self~noAutoDetection

::method execute unguarded
   expose message title sleeping earlyReply sx sy pos

   s = self~getTextSizeDu(message)
   sx = s~width
   sy = s~height
   self~createCenter(sx+20, sy + 20, title, "", , , , 1)
   self~executeAsync( , 'SHOWTOP')
   if sleeping >= 0 then do
      if earlyReply then reply
      ret = msSleep(sleeping)
      self~start("endAsyncExecution")
      self~ok:super
   end
   else do
      self~start("endAsyncExecution")
   end

::method initDialog
   expose pos

   if pos \== .nil then self~moveTo(pos)
   .SystemMenu~new(self)~disable(.SystemMenu~SC_CLOSE)


-- This class provides a simple dialog with a title, a message, one entry line,
-- an OK and a Cancel push button.
::class 'InputBox' subclass UserDialog public

::constant  IDC_EDIT   101
::attribute sx
::attribute sy
::attribute editText unguarded

::method init
   expose message title datas. size
   use arg message, title, default = "", size = 0
   self~init:super
   self~editText = default

::method defineDialog
   expose message size dlgy
   if size = 0 then size = self~sx
   self~createStaticText(-1, 10, 10, self~sx + 2, self~sy, , message)
   self~addLine(10, self~sy + 4 + 10, size)
   self~createPushButtonGroup(self~sx-80, dlgy - 18, 0, 0, "&Ok 1 OK &Cancel 2 CANCEL", 1, "DEFAULT")

::method addLine
   use arg x, y, l
   self~createEdit(self~IDC_EDIT, x, y, l)

::method execute
   expose message title dlgy size

   s = self~getTextSizeDu(message)
   self~sx = max(s~width, 100, size)
   self~sy = s~height

   dlgy = (self~sy + 4) * 2 + 36
   dlgx = self~sx + 20
   if dlgx < 110 then dlgx = 110

   self~createCenter(dlgx, dlgy, title,,,,,4)
   self~execute:super("SHOWTOP")
   if self~initCode = 1 then return self~editText
   else return ""

::method initDialog
   self~newEdit(self~IDC_EDIT)~setText(self~editText)

::method ok unguarded
   self~editText = self~newEdit(self~IDC_EDIT)~getText
   return self~ok:super

::method initAutoDetection
   self~noAutoDetection


-- A subclass of an InputBox dialog that masks the user input. Suitable for
-- asking the user for a password.
::class 'PasswordBox' subclass InputBox public

::method addLine
   use arg x, y, l
   self~createPasswordEdit(self~IDC_EDIT, x, y, l)


-- A subclass of an InputBox dialog that only accepts numerical data.
::class 'IntegerBox' subclass InputBox public

::method validate
   text = self~newEdit(self~IDC_EDIT)~getText
   if \ text~dataType('W') then do
      msg = "You did not enter numerical data"
      title = 'Data Input Error'
      j = MessageDialog(msg, self~hwnd, title, 'OK', 'ERROR')
      return .false
   end
   else return .true


::class 'MultiInputBox' subclass UserDialog public

-- This class is too hard to implement without automatic data detection and
-- still retain backwards compatibility.  So, we explicitly set it to on for
-- this dialog.  That way it will work if the user has globaly set it to off or
-- on.
::method initAutoDetection
   self~autoDetection

::method init
   expose message title datas. entries. len
   use arg message, title, entries., datas., len
   if arg(5,"o") = 1 then len = 0
   self~init:super(datas.)

::method defineDialog
   expose message sx sy len dlgx dlgy entries. maxlen
   self~createStaticText(-1, 10, 10, sx+2, sy, , message)
   self~createEditInputStem(101, 10, sy+4+10, maxlen+4, len, entries.)
   self~createPushButtonGroup(dlgx-100, dlgy - 18, 0, 0, "&Ok 1 OK &Cancel 2 CANCEL", 1, "DEFAULT")

::method execute
   expose message title sx sy datas. dlgx dlgy len entries. maxlen

   s = self~getTextSizeDu(message)
   sx = s~width
   sy = s~height
   ll = 0; count = 0

   do while var("entries."count+1) = 1
      count = count + 1
      s = self~getTextSizeDu(entries.count)
      if s~width > ll then ll = s~width
   end

   if len = 0 then len = max(sx - ll, 50)
   maxlen = ll
   dlgy = count * (sy * 2) + trunc((sy*count)/4) + 56

   if sx >= len + ll + 4 then dlgx = (sx+24)
   else dlgx = (len + ll + 24)
   if dlgx < 110 then dlgx = 110

   self~createCenter(dlgx, dlgy, title,,,,, count*2+5)
   self~execute:super("SHOWTOP")
   return self~initCode


::class 'ListChoice' subclass UserDialog public

::constant  IDC_LB   101
::attribute sx
::attribute sy
::attribute dlgx
::attribute dlgy
::attribute lenx
::attribute leny
::attribute message
::attribute useVScroll
::attribute lbSelection unguarded

::method init
   expose message title input. lenx leny
   use arg message, title, input., lenx = 0, leny = 0, predev = ''

   self~init:super
   self~lbSelection = predev
   s = self~getTextSizeDu(message)
   self~sx = s~width
   self~sy = s~height
   self~message = message
   self~useVScroll = .false

::method defineDialog
   expose message sx sy lenx leny dlgx dlgy
   self~createStaticText(-1, 10, 10, sx + 2, sy, , message)
   if self~useVScroll then style = "VSCROLL"
   else style = "PARTIAL"
   self~createListBox(self~IDC_LB, 10, sy + 4 + 10, lenx, leny+4, style)
   self~createPushButtonGroup(dlgx - 100, dlgy - 18, 0, 0, "&Ok 1 OK &Cancel 2 CANCEL", 1, "DEFAULT")

::method initDialog
   expose count input.
   do i = 1 to count
      self~addListEntry(self~IDC_LB, input.i)
   end
   self~setListBoxData(self~IDC_LB, self~lbSelection)

::method execute
   expose message title sx sy input. count lenx leny dlgx dlgy useVScroll

   s = self~getTextSizeDu(message)
   sx = s~width
   sy = s~height

   ll = 0; count = 0
   do while var("input."count+1) = 1
      count = count + 1
      s = self~getTextSizeDu(input.count)
      if s~width > ll then ll = s~width
   end

   goodHeight = (count * self~sy) + 1

   if self~lenx = 0 then self~lenx = max(self~sx,ll+5)
   if self~leny = 0 then do
      if count > 15 then do
         self~leny = self~sy * 15
         useVScroll = .true
         self~useVScroll = .true
         self~recalcListBoxWidth(ll + 5)
      end
      else do
         self~leny = goodHeight
      end
   end
   else do
      if self~leny < goodHeight then do
         self~leny = self~sy * 15
         useVScroll = .true
         self~recalcListBoxWidth(ll + 5)
      end
   end

   self~dlgy = self~leny+(self~sy+4)+34

   if self~sx >= self~lenx then self~dlgx = self~sx + 20; else self~dlgx = self~lenx + 20
   if self~dlgx < 110 then self~dlgx = 110

   self~createCenter(self~dlgx, self~dlgy, title,,,,, 4)
   self~execute:super("SHOWTOP")

   if self~initCode = 1 then return self~lbSelection
   else return ""

::method recalcListBoxWidth private
   use strict arg neededLBWidth
   sbWidth = self~getScrollBarWidth
   tmpLenX = neededLBWidth + sbWidth
   if tmpLenX > self~sx then self~lenx = tmpLenX

::method getScrollBarWidth private
   SM_CXVSCROLL = 20
   size = .Size~new
   size~width = .DlgUtil~getSystemMetrics(SM_CXVSCROLL)
   self~pixel2dlgUnit(size)
   if size~width > 15 then return size~width + 2
   else return size~width

::method ok unguarded
   self~lbSelection = self~newListBox(self~IDC_LB)~selected
   return self~ok:super

::method initAutoDetection
   self~noAutoDetection



::class 'MultiListChoice' subclass ListChoice public

::method defineDialog
   if self~useVScroll then style = "MULTI VSCROLL TABULATORS"
   else style = "MULTI PARTIAL TABULATORS"
   self~createStaticText(-1, 10, 10, self~sx+2, self~sy, , self~message)
   self~createListBox(101, 10, self~sy+4+10, self~lenx, self~leny+4, style, "DATA")
   self~createPushButtonGroup(self~dlgx-100, self~dlgy - 18, 0, 0, "&Ok 1 OK &Cancel 2 CANCEL", 1, "DEFAULT")

::method ok unguarded
   self~lbSelection = self~newListBox(self~IDC_LB)~selectedIndexes
   return self~ok:.UserDialog



::class 'CheckList' subclass UserDialog public

  /* Entries is a stem variable with all the titles for the check boxes */
  /* Datas is a stem variable you can use to preselect the check boxes */
  /* 'Datas.i=1' means there will be a check mark on the i-th box */
::method init
   expose message title datas. entries. len max
   use arg message, title, entries., datas., len, max
   if arg(5,"o") = 1 then len = 0
   if arg(6,"o") = 1 then max = 0
   self~init:super(datas.)

-- Punt on this class and use automatic data detection to retain backwards
-- compatibility.  We explicitly set it to on for this dialog.  That way it will
-- work if the user has globaly set it to off or on.
::method initAutoDetection
   self~autoDetection

::method defineDialog
   expose message sx sy len dlgx dlgy entries. placex max
   self~createStaticText(-1, 10, 10, sx+2, sy, , message)
   self~createCheckBoxStem(101, placex, sy+4+10, len, entries., max)
   self~createPushButtonGroup(dlgx-100, dlgy - 18, 0, 0, "&Ok 1 OK &Cancel 2 CANCEL", 1, "DEFAULT")

::method execute
   expose message title sx sy datas. dlgx dlgy len entries. placex max

   s = self~getTextSizeDu(message)
   sx = s~width
   sy = s~height
   ll = 0; count = 0
   do while var("entries."count+1) = 1
      count = count + 1
      s = self~getTextSizeDu(entries.count)
      if s~width > ll then ll = s~width
   end

   if max = 0 then max = count
   dlgy = max * trunc(sy * 1.5) + sy + 60
   placex = 10
   columns = (count % max)
   if  (count // max) > 0 then columns = columns +1

   if sx >= (ll + 20) * columns then
   do
      dlgx = (sx+24)
      if columns = 1 then placex = trunc((dlgx - ll - 20) /2)
   end
   else dlgx = (ll + 20) * columns + 24
   if dlgx < 110 then dlgx = 110

   self~createCenter(dlgx, dlgy, title,,,,, count+5)
   self~execute:super("SHOWTOP")
   return self~initCode



::class 'SingleSelection' subclass UserDialog public

::constant  MIN_DLGCX   110  -- minimum size to accomdate ok / cancel buttons
::constant  MIN_RB_ID   101  -- first radio button resource ID

::attribute selected unguarded

::method init
    expose message title entries. preSel len max
    use strict arg  message, title, entries., preSel = 1, len = 0, max = 0
    self~init:super
    self~selected = self~MIN_RB_ID - 1 + preSel

::method defineDialog
    expose entries. dlgCX dlgCY msgCX msgCY message groupBoxX staticX len max

    buttonTxt = "&Ok 1 OK &Cancel 2 CANCEL"

    self~createStaticText(-1, staticX, 10, msgCX + 2, msgCY, , message)
    self~createRadioButtonStem(self~MIN_RB_ID, groupBoxX, msgCY + 4 + 10, len, entries., max)
    self~createPushButtonGroup(dlgCX - 100, dlgCY - 18, 0, 0, buttonTxt, 1, "DEFAULT")

::method initDialog
    rb = self~newRadioButton(self~selected)
    if rb == .nil then return
    rb~check

::method execute
    expose dlgCX dlgCY title count

    self~calcSizes
    self~createCenter(dlgCX, dlgCY, title, , , , , count + 5)

    self~execute:super("SHOWTOP")
    if self~initCode = 1 then return (self~selected - self~MIN_RB_ID + 1)
    else return ""

::method ok unguarded
    expose count

    do i = self~MIN_RB_ID to (self~MIN_RB_ID + count - 1)
        if self~newRadioButton(i)~checked then do
            self~selected = i
            leave
       end
    end
    return self~ok:super

::method calcSizes private
    expose entries. max preSel message len msgCX msgCy count dlgCX dlgCY groupBoxX staticX

    s = self~getTextSizeDu(message)
    msgCX = s~width
    msgCY = s~height
    ll = 0; count = 0
    do while var("entries."count + 1) = 1
        count += 1
        if len == 0 then do
            s = self~getTextSizeDu(entries.count)
            if s~width > ll then ll = s~width
        end
    end
    if len <> 0 then ll = len
    else ll += 20

    if max = 0 then max = count
    dlgCY = max * trunc(msgCY * 1.5) + msgCY + 60
    dlgCX = self~getMinDlgCX
    groupBoxX = 10
    staticX = 10
    columns = (count % max)
    if  (count // max) > 0 then columns = columns + 1

    groupBoxCX = ll * columns
    if msgCX >= groupBoxCX then do
        if (msgCX + 24) > dlgCX then dlgCX = (msgCX + 24)
    end
    else do
        if groupBoxCX + 24 > dlgCX then dlgCX = groupBoxCX + 24
    end

    if groupBoxCX + 4 < dlgCX then do
        groupBoxX = trunc((dlgCX - groupBoxCX) / 2)
        if groupBoxCX >= msgCX then staticX = groupBoxX
        else staticX = trunc((dlgCX - msgCX) / 2)
    end

::method getMinDlgCX private
    expose title

    s = self~getTextSizeTitleBar(title)

    padding = 18
    s~width += (2 * .SM~cxFixedFrame) + .SM~cxSize + .SM~cxSmIcon + padding
    self~pixel2dlgUnit(s)

    if self~MIN_DLGCX < s~width then return s~width
    else return self~MIN_DLGCX

::method initAutoDetection
    self~noAutoDetection


::class 'ProgressDialog' public subclass UserDialog

::constant IDC_PB_MAIN    100
::constant IDC_ST_MSG     101
::constant IDC_ST_STATUS  102

::constant BUTTON_CX      35
::constant BUTTON_CY      14
::constant DLG_WIDTH      91  -- 2 x button width + margins + interbutton spacing
::constant CAPTION_TEXT   "Application Processing ..."
::constant INCR_STEP      1
::constant MARQUEE_PAUSE  100
::constant MSG_TEXT       "Background processing is taking place.  Please be patient."
::constant STATUS_TEXT    "Status: "
::constant PADDING_DU     7
::constant RANGE_MAX      100
::constant RANGE_MIN      0

::attribute absoluteWidth
::attribute canCancel
::attribute captionText
::attribute incrStep
::attribute initialStatusText
::attribute marqueeMode
::attribute marqueePause
::attribute msgHeight    -- Number of lines, default 1
::attribute msgText
::attribute noMsg
::attribute noStatus
::attribute rangeMax
::attribute rangeMin
::attribute width
::attribute worker unguarded private

::method init
    use strict arg capt = (self~CAPTION_TEXT), msg = (self~MSG_TEXT), min = (self~RANGE_MIN), max = (self~RANGE_MAX), incr = (self~INCR_STEP)
    self~init:super

    self~captionText = capt
    self~msgText     = msg
    self~rangeMax    = max
    self~rangeMin    = min
    self~incrStep    = incr
    self~setDefaults

::method begin
    expose width height
    use strict arg

    self~calcSizes
    if self~createCenter(width, height, self~captionText) then do
        self~popup('ShowTop')
        ret = 0
    end
    else do
        self~initCode = 1
        msg   = "Failed to create underyling dialog."
        title = 'ooDialog - Unexpected Error'
        r = MessageDialog(msg, , title, 'OK', 'ERROR')
        ret = 1
    end
    return ret

::method complete unguarded
    expose pb
    use strict arg
    if self~initCode <> 0 then return
    if \ pb~isA(.ProgressBar) then return
    if self~marqueeMode then pb~setMarquee(.false)
    else pb~setPos(self~rangeMax)

::method doStatus unguarded private
    expose statusBar
    use strict arg text
    if self~noStatus then return
    if self~initCode <> 0 then return
    guard on when statusBar~isA(.Static)
    statusBar~setText(text)

::method endNow unguarded
    return self~ok:super

::method increase unguarded
    expose pb
    use strict arg incr = (self~incrStep)
    if self~marqueeMode then return
    if self~initCode <> 0 then return
    guard on when pb~isA(.ProgressBar)
    pb~step(incr)

::method setInterruptible unguarded external "LIBRARY oodialog pd_setInterruptible"
::method updateStatus unguarded
    use strict arg text
    self~doStatus("Status:" text)

::method updateStatusText unguarded
    use strict arg text
    self~doStatus(text)

::method calcSizes private
    expose width height lineHeight
    use strict arg

    pad = self~PADDING_DU
    if self~noMsg, self~noStatus then do
        tempText = self~MSG_TEXT
    end
    else if \ self~noMsg, self~msgHeight < 2 then do
        tempText = self~msgText
    end
    else do
        tempText = self~MSG_TEXT
    end
    size = self~getTextSizeDU(tempText)
    lineHeight = size~height

    height = pad
    if \ self~noMsg then do
        height += lineHeight * self~msgHeight
    end
    if \ self~noStatus then do
        height += pad + lineHeight
    end

    if height > pad then height += pad
    height += lineHeight + pad

    if self~canCancel then do
        height += pad + self~BUTTON_CY
    end

    if self~absoluteWidth then do
        width = self~width
    end
    else do
      cx = size~width + (2 * pad)
      if cx >= self~DLG_WIDTH then width = cx
      else width = self~DLG_WIDTH
    end

::method setDefaults private

    self~msgHeight         = 1
    self~noMsg             = .false
    self~noStatus          = .false
    self~initialStatusText = self~STATUS_TEXT
    self~absoluteWidth     = .false
    self~width             = self~DLG_WIDTH
    self~marqueePause      = self~MARQUEE_PAUSE
    self~marqueeMode       = .false
    self~worker            = .nil
    self~canCancel         = .false

::method defineDialog
    expose width height lineHeight
    pad = self~PADDING_DU
    style = 'SMOOTH'
    if self~marqueeMode then style ||= ' MARQUEE'
    cx   = width - 2 * pad
    curY = pad
    if \ self~noMsg then do
      cy = lineheight * self~msgHeight
      self~createStaticText(self~IDC_ST_MSG, pad, curY, cx, cy, , self~msgText)
      curY += cy + pad
    end
    if \ self~noStatus then do
        self~createStaticText(self~IDC_ST_STATUS, pad, curY, cx, lineHeight, , "" )
        curY += lineHeight + pad
    end
    self~createProgressBar(self~IDC_PB_MAIN, pad, curY, cx, lineHeight, style)
    curY += lineHeight + pad
    if self~canCancel then do
        self~createPushButton(IDCANCEL, width - pad - self~BUTTON_CX, curY, self~BUTTON_CX, self~BUTTON_CY, , 'Cancel')
    end

::method initDialog
    expose pb statusBar

    pb = self~newProgressBar(self~IDC_PB_MAIN)
    if self~marqueeMode then do
        pb~setMarquee(.true, self~marqueePause)
    end
    else do
        pb~setRange(self~rangeMin, self~rangeMax)
        pb~setStep(self~incrStep)
        pb~step
    end
    if \ self~noMsg then do
        self~newStatic(self~IDC_ST_MSG)~setText(self~msgText)
    end
    if \ self~noStatus then do
        statusBar = self~newStatic(self~IDC_ST_STATUS)
        statusBar~setText(self~initialStatusText)
    end

-- Don't let the user close the dialog, unless the work can be stopped, or it
-- is allowed.
::method ok unguarded
::method cancel unguarded
    expose worker

    if worker <> .nil then do
        if worker~interruptible then do
            worker~interrupt
            return
        end
        self~giveStatus(.true)
        return
    end
    else if self~canCancel then do
        return self~cancel:super
    end
    self~giveStatus(.false)

::method giveStatus unguarded private
    expose pb worker
    use strict arg tryLater
    reply 0

    if self~marqueeMode then do
        msg = "Processing is not done yet, and can" || .endOfLine || -
              "not be canceled at this time."       || .endOfLine
    end
    else do
        r = pb~getFullRange
        percentDone = trunc((pb~getPos / (r~max - r~min)) * 100)
        msg = "Processing is only" percentDone"% done, and" || .endOfLine -
              "can not be canceled at this time."           || .endOfLine
    end
    if tryLater then do
        msg ||= "(Try canceling later.)" || .endOfLine
    end
    msg ||= .endOfLine || "Please be patient."

    ret = MessageDialog(msg, , self~captionText, 'OK', 'INFORMATION')

::method initAutoDetection
    self~noAutoDetection


::class 'Interruptible' public mixinclass Object
::method interrupt     unguarded abstract
::method interruptible unguarded abstract

::class 'Alerter' public inherit Interruptible
::attribute isCanceled get
::method init
    expose isCanceled
    isCanceled = .false
::method interruptible unguarded
    return .true
::method interrupt unguarded
    expose isCanceled
    isCanceled = .true


/* - - - - - - - - - - - - - Public routines - - - - - - - - - - - - - - - - -*/

::routine askDialog public
   use strict arg info, defaultButton = 'Y'
   miscStyles = "SETFOREGROUND TASKMODAL"
   if defaultButton~left(1)~translate == 'N' then miscStyles ||= ' DEFBUTTON2'
   return (messageDialog(info, , "Question", "YESNO", "QUESTION", miscStyles) == 6)

::routine errorDialog public
   use strict arg info
   return messageDialog(info, , "Error", "OK", "HAND", "SETFOREGROUND TASKMODAL")

::routine fileNameDialog public external "LIBRARY oodialog fileNameDlg_rtn"
::routine findWindow public external "LIBRARY oodialog findWindow_rtn"
::routine infoDialog public
   use strict arg info
   return messageDialog(info, , "Information", "OK", "INFORMATION", "SETFOREGROUND TASKMODAL")

::routine locate public external "LIBRARY oodialog locate_rtn"
::routine messageDialog public external "LIBRARY oodialog messageDialog_rtn"
::routine msSleep public external "LIBRARY oodialog msSleep_rtn"
::routine play public external "LIBRARY oodialog play_rtn"
::routine screenSize public
   return .DlgUtil~screenSize

::routine simpleFolderBrowse public external "LIBRARY oodialog simpleFolderBrowse_rtn"
::routine winTimer public external "LIBRARY oodialog winTimer_rtn"
::routine routineTest public external "LIBRARY oodialog routineTest_rtn"  -- internal use only


/** The following routines are, mostly, duplicates of the public routines above.
 *  They are needed to maintain backward compatibilty with  pre-4.0.0, because
 *  both names were documented.  They are all deprecated.
 */
/* ----- Start deprecated routines. ------------------------------------------*/
::routine binaryAnd public
  use strict arg n1, n2
  return .DlgUtil~and(n1, n2)

::routine errorMessage public
   use strict arg info
   return messageDialog(info, , "Error", "OK", "HAND", "SETFOREGROUND TASKMODAL")

::routine getFileNameWindow public external "LIBRARY oodialog fileNameDlg_rtn"
::routine getScreenSize public
  vals = .DlgUtil~screenSize
  return vals[1] vals[2] vals[3] vals[4]

::routine getSysMetrics public
  use strict arg index
  return .DlgUtil~getSystemMetrics(index)

::routine infoMessage public
   use strict arg info
   return messageDialog(info, , "Information", "OK", "INFORMATION", "SETFOREGROUND TASKMODAL")

::routine instMMFuncs public
  return 1

::routine playSoundFile public external "LIBRARY oodialog play_rtn"
::routine playSoundFileInLoop public external "LIBRARY oodialog play_rtn"
::routine sleepMS public external "LIBRARY oodialog msSleep_rtn"
::routine stopSoundFile public external "LIBRARY oodialog play_rtn"
::routine systemMetrics public
   use strict arg index
   return .DlgUtil~getSystemMetrics(index)

::routine yesNoMessage public
   use strict arg info, defaultButton = 'Y'
   miscStyles = "SETFOREGROUND TASKMODAL"
   if defaultButton~left(1)~translate == 'N' then miscStyles ||= ' DEFBUTTON2'
   return messageDialog(info, , "Question", "YESNO", "QUESTION", miscStyles) == 6

/* ----- End deprecated routines. --------------------------------------------*/

/*-------------------------- shortcut routines -------------------------------*/

::routine CheckList public
   use arg msg, title, labels, checks = (.array~new), lx = 0, max = 0
   num = labels~items
   do i=1 to num
      j = i+100
      lab.i = labels[i]
      if checks~hasIndex(i) then do
         if checks[i]~datatype('O') then dat.j = checks[i]
         else dat.j = 0
      end
      else dat.j = 0
   end
   dlg = .CheckList~new(msg, title, lab., dat., lx, max)
   if dlg~execute \= 1 then do; drop dlg; return .NIL; end
   ret = .array~new
   do j=101 to 100+num
      ret[j-100] = dat.j
   end
   drop dlg
   return ret

::routine InputBox public
   use arg msg, title, default = '', size = 0
   dlg = .InputBox~new(msg,title,default,size)
   ret = dlg~execute
   drop dlg
   return ret

::routine IntegerBox public
   use arg msg, title, default = '', size = 0
   dlg = .IntegerBox~new(msg,title,default,size)
   ret = dlg~execute
   drop dlg
   return ret

::routine ListChoice public
   use arg msg, title, list, lx = 0, ly = 0, predev = ""
   num = list~items
   do i=1 to num
      lst.i = list[i]
   end
   dlg = .ListChoice~new(msg, title, lst., lx, ly, predev)
   res = dlg~execute
   drop dlg
   if res = '' then return .nil
   else return res

::routine MultiInputBox public
   use arg msg, title, labels, datas, len = 0
   num = labels~items
   do i=1 to num
      j = i+100
      lab.i = labels[i]
      dat.j = datas[i]
   end
   dlg = .MultiInputBox~new(msg, title, lab., dat., len)
   if dlg~execute \= 1 then do; drop dlg; return .NIL; end
   ret = .array~new(num)
   do i=1 to num
      attr = labels[i]~changestr(' ','')~changestr('&','')
      Interpret 'ret[i] = dlg~'attr
   end
   drop dlg
   return ret

::routine MultiListChoice public
   use arg msg, title, list, lx = 0, ly = 0, predev = ""
   num = list~items
   do i=1 to num
      lst.i = list[i]
   end
   dlg = .MultiListChoice~new(msg, title, lst., lx, ly, predev)
   res = dlg~execute
   if res = '' then do; drop dlg; return .NIL; end
   ret = .array~new
   do i=1 to words(res)
      ret[i] = list[word(res,i)]
   end
   drop dlg
   return ret

::routine PasswordBox public
   use arg msg, title, default = "", size = 0
   dlg = .Passwordbox~new(msg,title,default,size)
   ret = dlg~execute
   drop dlg
   return ret

::routine SingleSelection public
   use strict arg msg, title, labels, preSel = 1, rbWidth = 0, max = 0

   do i = 1 to labels~items
      lab.i = labels[i]
   end
   dlg = .SingleSelection~new(msg, title, lab., preSel, rbWidth, max)
   res = dlg~execute
   drop dlg
   return res

::routine TimedMessage public
   use arg msg, title, duration, earlyReply = .false, pos = .nil
   if \ duration~datatype('W') then return -1
   if \ earlyReply~datatype('O') then earlyReply = .false
   dlg = .TimedMessage~new(msg,title,duration, earlyReply, pos)
   dlg~execute
   if duration < 0 then return dlg
   if \ earlyReply then drop dlg
   return 0


/**
 * The DlgArea and DlgAreaU classes.
 */

/* ========================================================================= */
::class 'DlgArea' public
/* ========================================================================= */
/*  define an area of your dialog to place controls on                       */
/*                                                                           */
/*  parms x, y, width, height [,margin]                                      */
/*                                                                           */
/*  x & y take offset as an argument,                                        */
/*  a -ve argument is from the right/bottom                                  */
/*                                                                           */
/*  methods & attributes                                                     */
/*  x()        offset from left (right if -ve)                               */
/*  y()        offset from top  (bottom if -ve)                              */
/*  w()        width                                                         */
/*  h()        height                                                        */
/*  wr         width remaining                                               */
/*  hr         height remaining                                              */
/*  l          left    }                                                     */
/*  t          top     }  Dimensions                                         */
/*  b          bottom  }  within margins                                     */
/*  r          right   }                                                     */
/*  move()     Specify new x,y coordinates                                   */
/*  resize()   Specify new width and height                                  */
/*                                                                           */
/*                                                                           */
/*  methods                                                                  */
/*  x & y  can take an offset argument which may be absolute or a percentage */
/*  w & h  can take a percentage as argument                                 */
/*         a parm of r to w or h means the remainder of the width or height  */
/*                                                                           */
/*  so to add a button 80% across your margined dialog for the remainder     */
/*  a = .DlgArea~new(10,10,150,110,5)                                        */
/*  self~createPushButton(a~x(80%),10,a~w(20%),a~h(10%), ,'Text','Method')   */
/*    or not using percentages is equivalent to                              */
/*  self~createPushButton(a~x(112),10,a~w * 0.2,a~h(10), ,'Text','Method')   */
/*    or not using the object would be equivalent to                         */
/*  self~createPushButton(117, 10, 28, 10, , 'Text','Method')                */
/*                                                                           */
/* ------------------------------------------------------------------------- */
/*               :                                  ^                        */
/*              top                                 :                        */
/*              <v.......width.............>     bottom                      */
/*              +--------------------------+   ^    :                        */
/* ......left..>|                       r  |   :    :                        */
/*              |                       v  |   :    :                        */
/*              |  +--------------------+  |   :    :                        */
/*              |  |+.x.>             ^ |  |   :    :                        */
/*              |  |:                 : |  |   :    :                        */
/*              |  |y                 : |  | height :                        */
/*              |  |:                 h |  |   :    :                        */
/*              |  |v                 : |  |   :    :                        */
/*              |  |<........w........+>|  |   :    :                        */
/*              |  |                  v |  |   :    :                        */
/*             ^|b>+--------------------+  |   :    :                        */
/*             m|                          |   :    :                        */
/*             v+--------------------------+   v    v                        */
/*              <m>                                                          */
/*.....right...............................>                                 */
/*                                                                           */
/*                                                                           */
/* ------------------------------------------------------------------------- */

/* ------------------------------------------------------------------------- */
::method init
/* ------------------------------------------------------------------------- */
arg left,top,width,height,margin

if margin~datatype('n')
then self~margin = margin~trunc
else self~margin = max(min(height % 7,5),1)

if top~datatype('n')
then self~top       = top~trunc
else self~top       = 10

if left~datatype('n')
then self~left      = left~trunc
else self~left      = 10

if width~datatype('n')
then self~width     = width~trunc
else self~width     = 100

if height~datatype('n')
then self~height    = height~trunc
else self~height    = 100


self~t = self~top  + self~margin
self~l = self~left + self~margin
self~b = self~top  + self~height - self~margin
self~r = self~left + self~width  - self~margin

self~lastX = 0
self~lastY = 0

/* ------------------------------------------------------------------------- */
::method x
/* ------------------------------------------------------------------------- */
arg offset
self~lastX='0'||Offset

if offset~pos('%') > 0
then do
   offset = offset~changestr('%','')
   if offset~datatype('n')
   then do
      if offset < 0 then offset = 100 + offset          /* from right margin */
      return trunc(self~left + self~margin + (self~w * (offset / 100)))
   end
   else return self~left + self~margin
end
else if offset~datatype('n')
     then if offset >= 0
          then return trunc(self~left + self~margin + offset) /* x from left */
          else return trunc(self~left + self~width - self~margin + offset) /* right */
else return self~left + self~margin

/* ------------------------------------------------------------------------- */
::method y
/* ------------------------------------------------------------------------- */
arg offset
self~lastY = '0'||offset

if offset~pos('%') > 0
then do
   offset = offset~changestr('%','')
   if offset~datatype('n')
   then do
      if offset < 0 then offset = 100 + offset          /* from right margin */
      return trunc(self~top + self~margin + (self~h * (offset / 100)))
   end
   else return self~top + self~margin
end
else if offset~datatype('n')
     then if offset >= 0
          then return trunc(self~top + self~margin + offset)
          else return trunc(self~top + self~height - self~margin + offset)
else return self~top + self~margin

/* ------------------------------------------------------------------------- */
::method h
/* ------------------------------------------------------------------------- */
arg pc

if pc = 'R' then return self~hr                       /* height is remainder */

h = self~height - (2 * self~margin)

if pc~pos('%') > 0
then return trunc(h * (pc~changestr('%','') / 100))
else return trunc(h)

/* ------------------------------------------------------------------------- */
::method HR
/* ------------------------------------------------------------------------- */

if self~lastY~pos('%') = 0                                 /* Y was absolute */
then return self~top + self~height - self~margin - self~lastY
else return self~h(100 - self~lastY~changestr('%','')||'%')       /* Y was % */

/* ------------------------------------------------------------------------- */
::method w
/* ------------------------------------------------------------------------- */
arg pc

if pc = 'R' then return self~wr                       /* width  is remainder */

w = self~width - (2 * self~margin)

if pc~pos('%') > 0
then return trunc(w * (pc~changestr('%','') / 100))
else return w

/* ------------------------------------------------------------------------- */
::method wr
/* ------------------------------------------------------------------------- */

if self~lastX~pos('%') = 0                                 /* X was absolute */
then return self~left + self~width - self~margin - self~lastX
else return self~w(100 - self~lastX~changestr('%','')||'%')       /* X was % */

/* ----------------------- compatibility methods --------------------------- */
::method cx    ; return self~w(arg(1))         -- Compatibility version of w
::method cy    ; return self~h(arg(1))         -- Compatibility version of h
::method sizeX ; return self~width
::method sizeY ; return self~height
/* ------------------------------------------------------------------------- */
::attribute t
::attribute l
::attribute b
::attribute r
::attribute top
::attribute left
::attribute width
::attribute height
::attribute margin
::attribute lastX           private
::attribute lastY           private

/* ========================================================================= */
::class 'DlgAreaU' subclass DlgArea public -- DlgAreaUniversal - Whole of Dialog
/* ========================================================================= */
/*  define the Area of the calling Dialog                                    */
/*                                                                           */
/*  parms callingDialog [,margin]                                            */
/*                                                                           */
/*  methods & attributes                                                     */
/*  resize     Aids in Dynamically Resizing Dialogs - See Documentation      */
/*  correctionFactor                                - See Documentation      */
/*                                                                           */
::method init
/* ------------------------------------------------------------------------- */
expose dlgObjList dlgObject
use arg dlgObj, margin, noResize, noMove

dlgObject = dlgObj

if \noResize~isA(.Set) then noResize = .Set~new
if \noMove~isA(.Set) then noMove = .Set~new
self~noResize = noResize
self~noMove   = noMove

self~resolveSetIDs

if \margin~datatype('n') then margin = 5

self~correctionFactor = 1.05

self~init:super(0,0,dlgObj~sizeX,dlgObj~sizeY,margin)

self~updateOnResize = .true
self~originalWidth  = dlgObj~sizeX
self~originalHeight = dlgObj~sizeY
self~lastError      = .nil

CreateControlTypes = .set~of('BITMAPBUTTON', 'CHECKBOX', 'COMBOBOX', 'TAB', -
  'PUSHBUTTON', 'RADIOBUTTON', 'DATETIMEPICKER', 'LISTVIEW', 'PASSWORDEDIT',    -
  'PROGRESSBAR', 'SCROLLBAR', 'TRACKBAR', 'BLACKFRAME', 'BLACKRECT', 'LISTBOX', -
  'ETCHEDHORIZONTAL', 'ETCHEDVERTICAL', 'GRAYRECT', 'GRAYFRAME', 'GROUPBOX',    -
  'STATIC', 'STATICFRAME', 'STATICIMAGE', 'STATICTEXT', 'TREEVIEW', 'UPDOWN',   -
  'WHITEFRAME', 'WHITERECT', 'MONTHCALENDAR', 'EDIT'                            -
)

-- Analyze the callers defineDialog Method
DDSourceArr=dlgObj~class~method('defineDialog')~source
DDSBuff=.mutableBuffer~new

-- Remove comments prefixed by --
do line over DDSourceArr
   parse var line line '--' .
   DDSBuff~Append(' '||line)
end
DDSource = DDSBuff~String ; Drop DDSBuff

-- remove comments within /*  */
do forever
   commEnd = DDsource~pos('*'||'/')
   if commEnd = 0 then leave
   commStart = DDSource~SubStr(1,CommEnd-1)~lastPos('/'||'*')
   if comStart=0
   then do
      self~lastError='Error in DlgAreaU Class: Unbalanced comments in defineDialog class of' Dlg
      leave
   end

   parse var DDSource front =(commStart) . =(commEnd) . +2 back
   DDSource = front back
end

-- copy of de-commented defineDialog source
DDSource1 = DDSource

-- re-create DlgArea objects within scope
do forever
   parse upper var DDSource1 front '.DLGAREA'DAMsg'('DAparms')'DDSource1
   do while DAParms~Countstr('(') > DAParms~CountStr(')')
      parse var DDSource1 fragment ')' DDSource1
      DAParms = DAParms||')'||fragment
   end


   if DAParms = '' then leave    -- we have got them all!

   -- parse out the refferer variable name
   parse value front~reverse with . '='DAVar .
   DAVar = DAVar~reverse~strip
   DAObj = DAVar
   sourceline = DAVar'=.DLGAREA'||DAMsg||'('||DAParms||')'
   select
      when DAMsg~Space(0) = 'U~NEW'  -- This is the DlgAreaU (self) obj def
         then interpret DAVar'=.DlgArea~new(0,0,'||self~w||','||self~h||','||self~margin||')'
      when DAMsg~Space(0) = '~NEW'   -- This is a DlgArea Obj definition
         then interpret DAVar'=.DlgArea~new('daparms')'
      otherwise
         self~lastError='DlgAreaU Class: Unable to parse:' SourceLine
   end
end

-- Now we parse out resizable widgets.
dlgObjList=.List~new
delim = '00'x

signal on syntax name parseerror
Parseerroroccured = 1 /* provisionally */

-- Save another copy of DDSource, we'll need it later.
DDSourceCopy = DDSource

-- First look for the create<Control> methods.
do forever
   parse upper var DDSource front 'CREATE'ObjName'('ObjParms')'DDSource1
   do while ObjParms~Countstr('(') > ObjParms~CountStr(')')
      parse var DDSource1 fragment ')' DDSource1
      ObjParms = ObjParms||')' fragment
   end

   if ObjParms = '' then leave
   if front~space(0)~right(5)='SELF~' then do
      sourcelinetxt = 'SELF~CREATE'||Objname||'('||Objparms||')'
      DDSource=DDSource1

      if CreateControlTypes~HasIndex(ObjName~strip) then
          parse var ObjParms ObjId','ObjX','ObjY','ObjW','ObjH','.
      else
          ObjId = ''       -- This createXXX method is ignored

      ObjId = ObjId~space(0)~strip( , "'")~strip( , '"')
      ObjId = dlgObject~resolveSymbolicID(ObjId)

      if ObjId > 0 then
         interpret 'dlgObjList~Insert(ObjId"@"' ObjX '"@"' ObjY '"@"' ObjW '"@"' ObjH ')'
   end
   else do
      -- skip past this create
      parse var DDSource 'CREATE'DDSource
   end
end

-- Now look for all the deprecated add<Control> methods.
DDSource = DDSourceCopy

do forever
   parse upper var DDSource front 'ADD'ObjName'('ObjParms')'DDSource1
   do while ObjParms~Countstr('(') > ObjParms~CountStr(')')
      parse var DDSource1 fragment ')' DDSource1
      ObjParms = ObjParms||')' fragment
   end

   if ObjParms = '' then leave
   if front~space(0)~right(5)='SELF~' then do
      sourcelinetxt = 'SELF~ADD'||Objname||'('||Objparms||')'
      DDSource=DDSource1
      select
         when 'BITMAPBUTTON BUTTON PROGRESSBAR SCROLLBAR'~Wordpos(ObjName~strip) > 0 then
            parse var ObjParms ObjId','ObjX','ObjY','ObjW','ObjH','.
         when 'CHECKBOX COMBOBOX ENTRYLINE LISTBOX LISTCONTROL PASSWORDLINE RADIOBUTTON SLIDERCONTROL TABCONTROL'~Wordpos(ObjName~strip) > 0 then
            parse var ObjParms ObjId','.','ObjX','ObjY','ObjW','ObjH','.
         when 'BLACKFRAME BLACKRECT GRAYRECT GRAYFRAME TREECONTROL WHITEFRAME WHITERECT'~Wordpos(ObjName~strip) > 0 then
            parse var ObjParms ObjX','ObjY','ObjW','ObjH','.','ObjId','.
         when 'GROUPBOX TEXT'~Wordpos(ObjName~strip) > 0 then
            parse var ObjParms ObjX','ObjY','ObjW','ObjH','.','.','ObjId','.
         otherwise
            ObjId = ''     -- This addXXX method is ignored
      end

      ObjId = ObjId~space(0)~strip( , "'")~strip( , '"')
      ObjId = dlgObject~resolveSymbolicID(ObjId)

      if ObjId > 0 then
         interpret 'dlgObjList~Insert(ObjId"@"' ObjX '"@"' ObjY '"@"' ObjW '"@"' ObjH ')'
   end
   else do
     -- skip past this add
      parse var DDSource 'ADD'DDSource
   end
end

Parseerroroccured = 0

parseerror:
signal off syntax

if parseerroroccured then self~lastError = 'DlgAreaU class could not parse' sourcelinetxt


/* ------------------------------------------------------------------------- */
::method noResizePut
/* ------------------------------------------------------------------------- */
/* This method allows the user to place dialog controls in the noResize set  */
/* using symbolic IDs.                                                       */
/* ------------------------------------------------------------------------- */
expose dlgObject
   use strict arg id

   id = dlgObject~getResourceID(id)
   self~noResize~put(id)


/* ------------------------------------------------------------------------- */
::method noMovePut
/* ------------------------------------------------------------------------- */
/* This method allows the user to place dialog controls in the noMove set    */
/* using symbolic IDs.                                                       */
/* ------------------------------------------------------------------------- */
expose dlgObject
   use strict arg id

   id = dlgObject~getResourceID(id)
   self~noMove~put(id)


/* ------------------------------------------------------------------------- */
::method resolveSetIDs private
/* ------------------------------------------------------------------------- */
/* This method looks through the noMove and noResize sets and replaces any   */
/* symbolic resource IDs with the correct numeric ID.  If a symbolic ID can  */
/* not be resolved, it is removed from the set.                              */
/* ------------------------------------------------------------------------- */
expose dlgObject noMove noResize

   do id over noMove
     id = noMove~remove(id)
     id = dlgObject~getResourceID(id)
     noMove~put(id)
   end

   do id over noResize
     id = noResize~remove(id)
     id = dlgObject~getResourceID(id)
     noResize~put(id)
   end


/* ------------------------------------------------------------------------- */
::method resize
/* ------------------------------------------------------------------------- */
/* this method needs to be called as follows:                                */
/* in your dialog init method place this line after call to the superclass   */
/* self~connectResize('OnResize')                                            */
/* the method resize would contain the following                             */
/* expose u /* our topmost dlgAreaClass exposed in defineDialog */           */
/* use arg dummy, sizeinfo    /* sizeinfo contains information about the     */
/*                                                  new width and height */  */
/* u~resize(self,sizeinfo)                                                   */
/* ------------------------------------------------------------------------- */
expose dlgObjList
  use arg dlg,data
  dlg~sizeX = .DlgUtil~loWord(data) % dlg~factorX
  dlg~sizeY = .DlgUtil~hiWord(data) % dlg~factorY

  wFactor   = (dlg~sizeX / self~originalWidth ) * self~correctionFactor
  hFactor   = (dlg~sizeY / self~originalHeight) * self~correctionFactor

  do dlgObjDef over dlgObjList
     parse var dlgObjdef DOid'@'DOx'@'DOy'@'DOw'@'DOh
     if \self~noResize~hasIndex(DOid)
     then dlg~resizeItem(Doid,DOw * wFactor,DOh * hFactor,"NOREDRAW")
     if \self~noMove~hasIndex(DOid)
     then dlg~moveItem(DOid,DOx * wFactor,DOy * hFactor,"NOREDRAW")
  end /* DO */

  if self~updateOnResize then dlg~update
/* ------------------------------------------------------------------------- */

::attribute originalWidth     private
::attribute originalHeight    private
::attribute dlgObject         private get
::attribute noResize
::attribute noMove
::attribute correctionFactor
::attribute lastError
::attribute updateOnResize

/**
 * Windows Dialog Interface for Open Object Rexx (ooRexx.)
 *
 * Animated button class.
 */

::class 'AnimatedButton' public

::attribute parentDlg unguarded
::attribute stopped   unguarded

::method init
     expose spritewin spos. sprite.

     if ARG() > 2 then
        use arg bid, bmpfrom, bmpto, movx, movy, bmpsizex, bmpsizey, dely, ix, iy, dlg
     else do
        use arg istring, dlg
        parse var istring bid "," bmpfrom"," bmpto"," movx"," movy"," bmpsizex"," bmpsizey"," dely"," ix"," iy
     end

     self~stopped = .false
     if bmpfrom~hasmethod("HASINDEX") then
         sprite.from = bmpfrom
     else do
         if bmpfrom~datatype("N") = 1 & bmpto \= 0 then sprite.from = bmpfrom
         else sprite.from = .local[bmpfrom]
     end
     sprite.to = bmpto
     sprite.movex = movx
     sprite.movey = movy
     sprite.sizex = bmpsizex
     sprite.sizey = bmpsizey
     sprite.delay = dely
     sprite.buttonid = bid
     sprite.smooth = 1
     sprite.step = 1

     self~parentDlg = dlg
     spritewin = self~parentDlg~getControlHandle(sprite.buttonid)
     parse value self~parentDlg~getWindowRect(spritewin) with spos.left spos.top spos.right spos.bottom

     spos.bottom = spos.bottom - spos.top
     spos.right = spos.right - spos.left
     spos.top = 0
     spos.left = 0

     spos.x = ix
     spos.y = iy


::method movepos unguarded
     expose spritewin spos. sprite.
     use arg move.x, move.y
     oldpos.x = spos.x
     oldpos.y = spos.y
     reset.x = 0
     reset.y = 0
     ss.x = 0
     ss.y = 0
     sr.x = sprite.sizex
     sr.y = sprite.sizey
     if sprite.smooth \= 1 then
     do
        ss.x = sprite.sizex
        ss.y = sprite.sizey
        sr.x = 0
        sr.y = 0
     end

     if (move.x > 0) then
     do
       if (spos.x + move.x + ss.x) >= spos.right then reset.x = 1
       else spos.x = spos.x + move.x
     end
     else if (move.x < 0) then do
       if (spos.x + move.x + sr.x) <= spos.left then reset.x = 1
       else spos.x = spos.x + move.x
     end

     if (move.y > 0) then
     do
        if (spos.y + move.y + ss.y) >= spos.bottom then reset.y = 1
        else spos.y = spos.y + move.y
     end
     else if (move.y < 0) then do
        if (spos.y + move.y + sr.y*(sprite.to\=0) ) <= spos.top then reset.y = 1
        else spos.y = spos.y + move.y
     end

     if self~parentStopped then return 1

     if (reset.x + reset.y) > 0 then do
        if reset.x = 1 then do
           if (move.x > 0) then
           do
              if self~hitright = 1 then spos.x = spos.left - sr.x
           end
           else if (move.x < 0) then do
              if self~hitleft = 1 then spos.x = spos.right - ss.x
           end
        end
        if reset.y = 1 then do
           if (move.y > 0) then
           do
              if self~hitbottom = 1 then spos.y = spos.top - sr.y*(sprite.to\=0)
           end
           else if (move.y < 0) then do
              if self~hittop = 1 then spos.y = spos.bottom - ss.y
           end
        end
        if self~parentStopped then return 1
        self~parentDlg~changeBitmapButton(sprite.buttonid, 0)
        /* self~parentDlg~clearRect(spritewin, oldpos.x, oldpos.y, (oldpos.x + sprite.sizex), (oldpos.y + sprite.sizey)) */
     end
     if self~parentStopped then return 1
     self~parentDlg~setBitmapPosition(sprite.buttonid, spos.x, spos.y);


::method setpos unguarded
     expose spritewin spos. sprite.
     use arg new.x, new.y

     if self~parentStopped then return 1
     self~parentDlg~changeBitmapButton(sprite.buttonid, 0)
     self~parentDlg~clearRect(spritewin, spos.x, spos.y, (spos.x + sprite.sizex), (spos.y + sprite.sizey))
     spos.x = new.x
     spos.y = new.y
     self~parentDlg~setBitmapPosition(sprite.buttonid, spos.x, spos.y);

::method getpos
     expose spos.
     use arg mypos.
     mypos.x = spos.x
     mypos.y = spos.y


::method moveseq unguarded
     expose spritewin spos. sprite.

     if sprite.to > 0 then
     do
        opts = ''
        do actsprite = sprite.from by sprite.step to sprite.to
           if (sprite.movex \= 0) | (sprite.movey \=0) then
              self~movepos(sprite.movex, sprite.movey)
           if self~parentStopped then return 1
           self~parentDlg~changeBitmapButton(sprite.buttonid, actsprite,,,,opts)
           if (sprite.delay \= 0) then ret = msSleep(sprite.delay)
        end
     end
     else do
        opts = "INMEMORY"
        do actsprite over sprite.from
           if (sprite.movex \= 0) | (sprite.movey \=0) then
              self~movepos(sprite.movex, sprite.movey)

           if self~parentStopped then return 1
           self~parentDlg~changeBitmapButton(sprite.buttonid, actsprite,,,,opts)
           if (sprite.delay \= 0) then ret = msSleep(sprite.delay)
        end
     end


::method moveto unguarded
     expose spos. sprite.
     use arg newx, newy

     if (sprite.movex > 0) then mx = 1; else mx = 0
     if (sprite.movey > 0) then my = 1; else my = 0
     if (mx = 1) & (my = 1) then
     do until (spos.x > newx) & (spos.y > newy)
        self~moveseq
     end
     else if (mx = 0) & (my = 0) then
     do until (spos.x < newx) & (spos.y < newy)
        self~moveseq
     end
     else if (mx = 1) & (my = 0) then
     do until (spos.x > newx) & (spos.y < newy)
        self~moveseq
     end
     else if (mx = 0) & (my = 1) then
     do until (spos.x < newx) & (spos.y > newy)
        self~moveseq
     end


::method run unguarded
   do until self~stopped | self~parentStopped
      self~moveseq
   end
   return 0

::method parentStopped unguarded
   return \ self~parentDlg~isDialogActive

::method stop unguarded
   self~stopped = .true

::method setfromto
   expose sprite.
   use arg ifrom, ito
   sprite.from = ifrom
   sprite.to = ito

::method setmove
   expose sprite.
   use arg xx,yy
   sprite.movex = xx
   sprite.movey = yy

::method setdelay
   expose sprite.
   use arg da
   sprite.delay = da

::method setsmooth
   expose sprite.
   use arg sm
   sprite.smooth = sm

::method setstep
   expose sprite.
   use arg st
   sprite.step = st

::method getsprite
   expose sprite.
   use arg osprite.
   do k over sprite.
      osprite.k = sprite.k
   end

::method setsprite
   expose sprite.
   use arg isprite.
   do k over isprite.
      sprite.k = isprite.k
   end

::method hitright unguarded
   return 1

::method hitleft unguarded
   return 1

::method hitbottom unguarded
   return 1

::method hittop unguarded
   return 1

/**
 * Windows Dialog Interface for Open Object Rexx (ooRexx.)
 *
 * This module contains the WindowsExtensions mixinclass. This class is
 * inherited by the PlainBaseDialog class and helps form the foundation of all
 * non-trivial dialogs.
 *
 * Some classes related to Windows resources are also included here.
 */

/**
 * The class WindowExtensions implements methods that are common to all windows,
 * no matter whether they are dialogs or dialog controls.  It's an extension to
 * the WindowBase mixin-class.
 *
 * Note that this mixin class contains (did contian) many methods that should
 * not be a part of a dialog control class.  It also contains (did contain) many
 * methods that would be bettor off in a separate class.  The original comment
 * above, does not seem to have been followed through on.
 */

::class 'WindowExtensions' public mixinclass Object

::method initWindowExtensions external "LIBRARY oodialog winex_initWindowExtensions"

::method createBrush unguarded external "LIBRARY oodialog winex_createBrush"
::method createFont unguarded external "LIBRARY oodialog winex_createFont"
::method createFontEx unguarded external "LIBRARY oodialog winex_createFontEx"
::method createPen unguarded external "LIBRARY oodialog winex_createPen"
::method deleteFont unguarded external "LIBRARY oodialog winex_deleteObject"
::method deleteObject unguarded external "LIBRARY oodialog winex_deleteObject"
::method drawAngleArc unguarded external "LIBRARY oodialog winex_drawAngleArc"
::method drawArc unguarded external "LIBRARY oodialog winex_drawArcOrPie"
::method drawLine unguarded external "LIBRARY oodialog winex_drawLine"
::method drawPie unguarded external "LIBRARY oodialog winex_drawArcOrPie"
::method drawPixel unguarded external "LIBRARY oodialog winex_drawPixel"
::method fillDrawing unguarded external "LIBRARY oodialog winex_fillDrawing"
::method fillRect unguarded external "LIBRARY oodialog winex_fillRect"
::method fontColor unguarded external "LIBRARY oodialog winex_fontColor"
::method fontToDC unguarded external "LIBRARY oodialog winex_objectToDC"
::method freeDC unguarded external "LIBRARY oodialog winex_freeDC"
::method getArcDirection unguarded external "LIBRARY oodialog winex_getSetArcDirection"
::method getDC unguarded external "LIBRARY oodialog winex_getDC"
::method getFont unguarded external "LIBRARY oodialog winex_getFont"
::method getPixel unguarded external "LIBRARY oodialog winex_getPixel"
::method getSysBrush unguarded external "LIBRARY oodialog winex_getSysBrush"
::method getTextAlign unguarded external "LIBRARY oodialog winex_getTextAlign"
::method getTextExtent unguarded external "LIBRARY oodialog winex_getTextExtent"
::method hScrollPos unguarded external "LIBRARY oodialog winex_getScrollPos"
::method loadBitmap unguarded external "LIBRARY oodialog winex_loadBitmap"
::method objectToDC unguarded external "LIBRARY oodialog winex_objectToDC"
::method opaqueText unguarded external "LIBRARY oodialog winex_textBkMode"
::method rectangle unguarded external "LIBRARY oodialog winex_rectangle"
::method removeBitmap unguarded external "LIBRARY oodialog winex_removeBitmap"
::method scroll unguarded external "LIBRARY oodialog winex_scroll"
::method setArcDirection unguarded external "LIBRARY oodialog winex_getSetArcDirection"
::method setFont unguarded external "LIBRARY oodialog winex_setFont"
::method setHScrollPos unguarded external "LIBRARY oodialog winex_setScrollPos"
::method setTextAlign unguarded external "LIBRARY oodialog winex_setTextAlign"
::method setVScrollPos unguarded external "LIBRARY oodialog winex_setScrollPos"
::method transparentText unguarded external "LIBRARY oodialog winex_textBkMode"
::method vScrollPos unguarded  external "LIBRARY oodialog winex_getScrollPos"
::method write unguarded external "LIBRARY oodialog winex_write"
::method writeDirect unguarded external "LIBRARY oodialog winex_writeDirect"


-- DEPRECATED
::method absRect2LogRect unguarded
   parse arg l, t, r, b
   ret.left = l/self~factorX
   ret.right = r/self~factorX
   ret.top = t/self~factorY
   ret.bottom = b/self~factorY
   return ret.

::method cursor_Arrow unguarded
  use strict arg
  forward to (.Mouse~new(self)) message 'ARROW'

::method cursor_AppStarting unguarded
  use strict arg
  forward to (.Mouse~new(self)) message 'APPSTARTING'

::method cursor_Cross unguarded
  use strict arg
  forward to (.Mouse~new(self)) message 'CROSS'

::method cursor_No unguarded
  use strict arg
  forward to (.Mouse~new(self)) message 'NO'

::method cursor_Wait unguarded
  use strict arg
  forward to (.Mouse~new(self)) message 'WAIT'

::method cursorPos unguarded
   forward to (.Mouse~new(self)) message 'GETCURSORPOS' continue
   return result~x result~y

::method logRect2AbsRect unguarded
   parse arg l, t, r, b
   ret.left = l*self~factorX
   ret.right = r*self~factorX
   ret.top = t*self~factorY
   ret.bottom = b*self~factorY
   return ret.

::method restoreCursorShape unguarded
  forward to (.Mouse~new(self)) message 'RESTORECURSOR'

::method setCursorPos unguarded
  forward to (.Mouse~new(self)) message 'SETCURSORPOS'


::class 'ResourceImage' public

::method init external "LIBRARY oodialog ri_init"
::method release external "LIBRARY oodialog ri_release"
::method handle external "LIBRARY oodialog ri_handle"
::method isNull external "LIBRARY oodialog ri_isNull"
::method systemErrorCode external "LIBRARY oodialog ri_systemErrorCode"
::method getImage external "LIBRARY oodialog ri_getImage"
::method getImages external "LIBRARY oodialog ri_getImages"


::class 'Image' public

::method toID class external "LIBRARY oodialog image_toID_cls"
::method getImage class external "LIBRARY oodialog image_getImage_cls"
::method fromFiles class external "LIBRARY oodialog image_fromFiles_cls"
-- ::method getGDIImage class external "LIBRARY oodialog image_getGDIImage_cls" future enhancement
::method fromIDs class external "LIBRARY oodialog image_fromIDs_cls"
::method userIcon class external "LIBRARY oodialog image_userIcon_cls"

::method colorRef class external "LIBRARY oodialog image_colorRef_cls"
::method getRValue class external "LIBRARY oodialog image_getRValue_cls"
::method getGValue class external "LIBRARY oodialog image_getGValue_cls"
::method getBValue class external "LIBRARY oodialog image_getBValue_cls"

::method init external "LIBRARY oodialog image_init"
::method release external "LIBRARY oodialog image_release"
::method handle external "LIBRARY oodialog image_handle"
::method isNull external "LIBRARY oodialog image_isNull"
::method systemErrorCode external "LIBRARY oodialog image_systemErrorCode"

::class 'ImageList' public
::method create class external "LIBRARY oodialog il_create_cls"

::method init external "LIBRARY oodialog il_init"
::method add external "LIBRARY oodialog il_add"
::method addIcon external "LIBRARY oodialog il_addIcon"
::method addImages external "LIBRARY oodialog il_addImages"
::method addMasked external "LIBRARY oodialog il_addMasked"
::method duplicate external "LIBRARY oodialog il_duplicate"
::method getCount external "LIBRARY oodialog il_getCount"
::method getIcon external "LIBRARY oodialog il_getIcon"
::method getImageSize external "LIBRARY oodialog il_getImageSize"
::method handle external "LIBRARY oodialog il_handle"
::method isNull external "LIBRARY oodialog il_isNull"
::method release external "LIBRARY oodialog il_release"
::method remove external "LIBRARY oodialog il_remove"
::method removeAll external "LIBRARY oodialog il_removeAll"


::class 'CreateWindows' public mixinclass Object

::method initCreateWindows external "LIBRARY oodialog cw_initCreateWindows"
::method createReBarWindow external "LIBRARY oodialog cw_createReBarWindow"
::method createStatusBarWindow external "LIBRARY oodialog cw_createStatusBarWindow"
::method createToolBarWindow external "LIBRARY oodialog cw_createToolBarWindow"



::class 'CustomDraw' public mixinclass EventNotification

::constant CDRF_DODEFAULT                  0  -- 0x00000000
::constant CDRF_NEWFONT                    2  -- 0x00000002
::constant CDRF_SKIPDEFAULT                4  -- 0x00000004
::constant CDRF_DOERASE                    8  -- 0x00000008  draw the background
::constant CDRF_SKIPPOSTPAINT            256  -- 0x00000100  don't draw the focus rect
::constant CDRF_NOTIFYPOSTPAINT           16  -- 0x00000010
::constant CDRF_NOTIFYITEMDRAW            32  -- 0x00000020
::constant CDRF_NOTIFYSUBITEMDRAW         32  -- 0x00000020  flags are the same, MS can distinguish by context
::constant CDRF_NOTIFYPOSTERASE           64  -- 0x00000040

::constant CDDS_PREPAINT                   1  -- 0x00000001
::constant CDDS_POSTPAINT                  2  -- 0x00000002
::constant CDDS_PREERASE                   3  -- 0x00000003
::constant CDDS_POSTERASE                  4  -- 0x00000004

::constant CDDS_ITEM                   65536  -- 0x00010000  the 0x000010000 bit means it's individual item specific
::constant CDDS_ITEMPREPAINT           65537  -- 0x00010001 (CDDS_ITEM | CDDS_PREPAINT)
::constant CDDS_ITEMPOSTPAINT          65538  -- 0x00010002 (CDDS_ITEM | CDDS_POSTPAINT)
::constant CDDS_ITEMPREERASE           65539  -- 0x00010003 (CDDS_ITEM | CDDS_PREERASE)
::constant CDDS_ITEMPOSTERASE          65540  -- 0x00010004 (CDDS_ITEM | CDDS_POSTERASE)
::constant CDDS_SUBITEM               131072  -- 0x00020000
::constant CDDS_SUBITEMPREPAINT       196609  -- 0x00030001  -- ooRexx defined for convenience
::constant CDDS_SUBITEMPOSTPAINT      196610  -- 0x00030002  -- ooRexx defined for convenience

::constant CLR_NONE               4294967295  --  0xFFFFFFFFL
::constant CLR_INVALID            4294967295  --  0xFFFFFFFFL
::constant CLR_DEFAULT            4278190080  --  xFF000000L

::method customDraw external "LIBRARY oodialog cd_init"
::method customDrawControl external "LIBRARY oodialog cd_customDrawControl"
::method RGB external "LIBRARY oodialog image_colorRef_cls"


::class 'ResizingAdmin' public mixinclass Object

::constant IDC_DEFAULT_PINTO_WINDOW     0

::attribute minSize get external   "LIBRARY oodialog ra_minSize"
::attribute minSize set external   "LIBRARY oodialog ra_setMinSize"
::attribute maxSize get external   "LIBRARY oodialog ra_maxSize"
::attribute maxSize set external   "LIBRARY oodialog ra_setMaxSize"

::method controlBottom external "LIBRARY oodialog ra_controlSide"
::method controlLeft external "LIBRARY oodialog ra_controlSide"
::method controlRight external "LIBRARY oodialog ra_controlSide"
::method controlSizing external "LIBRARY oodialog ra_controlSizing"
::method controlTop external "LIBRARY oodialog ra_controlSide"
::method defaultBottom external "LIBRARY oodialog ra_defaultSide"
::method defaultLeft external "LIBRARY oodialog ra_defaultSide"
::method defaultRight external "LIBRARY oodialog ra_defaultSide"
::method defaultSizing external "LIBRARY oodialog ra_defaultSizing"
::method defaultTop external "LIBRARY oodialog ra_defaultSide"
::method defineSizing
  return 0

::method noMaxSize external "LIBRARY oodialog ra_noMaxSize"
::method noMinSize external "LIBRARY oodialog ra_noMinSize"
::method pagedTab external "LIBRARY oodialog ra_pagedTab"
::method useDefaultSizing external "LIBRARY oodialog ra_useDefaultSizing"
::method wantSizeEnded external "LIBRARY oodialog ra_wantSizeEnded"

-- Internal use only
::method initResizing private  external "LIBRARY oodialog ra_initResizing"              -- Do not document

/**
 * Windows Dialog Interface for Open Object Rexx (ooRexx.)
 *
 * PropertySheetDialog, PropertySheetPage dialog, and ControlDialog  classes,
 * subclasses, and related interfaces.
 *
 * Do  not confuse a PropertySheetDialog with the wrongly named PropertySheet
 * class. The PropertySheet class is deprecated and not supported.
 *
 * PropertySheetDialog dialogs differ slightly from the normal ooDialog dialogs
 * because the underlying dialog is created and maintained by the operating
 * system.  ooDialog has no window procedure for a PropertySheetDialog, the
 * operating system is executing the window procedure.  This introduces some
 * subtle differences in the behavior of the dialog.  The ooDialog framework
 * can not define the dialog template, or receive the underly Property Sheet
 * window messages
 *
 * PropertySheetPage dialogs serve as the pages of the PropertySheetDialog.
 *
 * A control dialog is a dialog with a style that allows it work well as a
 * dialog within a top-level dialog.  The top-level dialog is both the owner and
 * the parent of the control dialog.  These dialogs work well as the content for
 * tab control pages.
 *
 * A control dialog is also a child of the owner / parent dialog.  The
 * popupAsChild() method also uses the concept of parent / child dialogs.  To
 * prevent confusion with that, the control dialog classes use the terms control
 * dialog and owner dialog rather than child and parent dialog .
 */



/*                    Property sheets and pages                               */

::class 'PropertySheetDialog' public subclass PlainBaseDialog

-- WM_USER == 0x400
::constant PSM_REBOOTSYSTEM             "0x046A"
::constant PSM_RESTARTWINDOWS           "0x0469"
::constant PSM_RECALCPAGESIZES          "0x0488"


::constant MAXPROPPAGES                 100
::constant ID_PSRESTARTWINDOWS            2
::constant ID_PSREBOOTSYSTEM              3  -- (ID_PSRESTARTWINDOWS | 0x1)

::constant IDC_TAB_IN_PROPSHEET            12320
::constant IDC_PB_APPLY_IN_PROPSHEET       12321


-- The application icon for the property sheet dialog
::attribute appIcon get unguarded
::attribute appIcon set unguarded external "LIBRARY oodialog psdlg_setAppIcon_atr"

-- The caption (title) for the property sheet dialog
::attribute caption get unguarded
::attribute caption set unguarded external "LIBRARY oodialog psdlg_setCaption_atr"

::attribute header get unguarded
::attribute header set unguarded external "LIBRARY oodialog psdlg_setHeader_atr"

-- Icons for each tab can come from an ImageList owned by the property dialog
::attribute imageList get unguarded
::attribute imageList set unguarded external "LIBRARY oodialog psdlg_setImageList_atr"

::attribute pages get unguarded external "LIBRARY oodialog psdlg_getPages_atr"

-- A resource image from which to get resources for the property sheet dialog
::attribute resources get unguarded
::attribute resources set unguarded external "LIBRARY oodialog psdlg_setResources_atr"

::attribute startPage get unguarded
::attribute startPage set unguarded external "LIBRARY oodialog psdlg_setStartPage_atr"

::attribute watermark get unguarded
::attribute watermark set unguarded external "LIBRARY oodialog psdlg_setWatermark_atr"

::method init external "LIBRARY oodialog psdlg_init"

::method addPage unguarded external "LIBRARY oodialog psdlg_addPage"
::method apply unguarded external "LIBRARY oodialog psdlg_apply"
::method cancelToClose unguarded external "LIBRARY oodialog psdlg_cancelToClose"
::method changed unguarded external "LIBRARY oodialog psdlg_changed"
::method enableWizButtons external "LIBRARY oodialog psdlg_enableWizButtons"
::method execute external "LIBRARY oodialog psdlg_execute"
::method getCurrentPageHwnd unguarded external "LIBRARY oodialog psdlg_getCurrentPageHwnd"
::method getPage unguarded external "LIBRARY oodialog psdlg_getPage"
::method getResult unguarded external "LIBRARY oodialog psdlg_getResult"
::method getTabControl unguarded external "LIBRARY oodialog psdlg_getTabControl"
::method hwndToIndex unguarded external "LIBRARY oodialog psdlg_hwndToIndex"
::method idToIndex unguarded external "LIBRARY oodialog psdlg_idToIndex"
::method indexToHwnd unguarded external "LIBRARY oodialog psdlg_indexToHandle"
::method indexToID unguarded external "LIBRARY oodialog psdlg_indexToID"
::method indexToPage unguarded external "LIBRARY oodialog psdlg_indexToHandle"
::method initDialog unguarded
    return 0
::method insertPage unguarded external "LIBRARY oodialog psdlg_insertPage"
::method pageToIndex unguarded external "LIBRARY oodialog psdlg_pageToIndex"
::method popup external "LIBRARY oodialog psdlg_popup"
::method popupAsChild external "LIBRARY oodialog psdlg_popupAsChild"
::method pressButton unguarded external "LIBRARY oodialog psdlg_pressButton"
::method querySiblings unguarded external "LIBRARY oodialog psdlg_querySiblings"
::method rebootSystem unguarded
    use strict arg
    self~sendWinIntMsg(self~PSM_REBOOTSYSTEM, 0, 0)
    return 0

::method recalcPageSizes unguarded
    use strict arg
    return self~sendWinIntMsg(self~PSM_RECALCPAGESIZES, 0, 0) != 0

::method restartWindows unguarded
    use strict arg
    self~sendWinIntMsg(self~PSM_RESTARTWINDOWS, 0, 0)
    return 0

::method removePage unguarded external "LIBRARY oodialog psdlg_removePage"
::method setCurSel unguarded external "LIBRARY oodialog psdlg_setCurSel"
::method setCurSelByID unguarded external "LIBRARY oodialog psdlg_setCurSelByID"
::method setButtonText unguarded external "LIBRARY oodialog psdlg_setButtonText"
::method setFinishText unguarded external "LIBRARY oodialog psdlg_setFinishText"
::method setHeaderSubTitle unguarded external "LIBRARY oodialog psdlg_resetPageText"
::method setHeaderTitle unguarded external "LIBRARY oodialog psdlg_resetPageText"
::method setNextText unguarded external "LIBRARY oodialog psdlg_setNextText"
::method setTitle unguarded external "LIBRARY oodialog psdlg_setTitle"
::method setWizButtons unguarded external "LIBRARY oodialog psdlg_setWizButtons"
::method showWizButtons unguarded external "LIBRARY oodialog psdlg_showWizButtons"
::method unchanged unguarded external "LIBRARY oodialog psdlg_unchanged"

::method test unguarded external "LIBRARY oodialog psdlg_test"


::class 'PropertySheetPage' mixinclass Object public

::constant PSNRET_NOERROR                     0
::constant PSNRET_INVALID                     1
::constant PSNRET_INVALID_NOCHANGEPAGE        2
::constant PSNRET_MESSAGEHANDLED              3
::constant PROP_SM_CXDLG                      212
::constant PROP_SM_CYDLG                      188
::constant PROP_MED_CXDLG                     227
::constant PROP_MED_CYDLG                     215
::constant PROP_LG_CXDLG                      252
::constant PROP_LG_CYDLG                      218

::method init class external "LIBRARY oodialog psp_init_cls"                                    -- Not to be documented

::attribute cx get external "LIBRARY oodialog psp_getcx"
::attribute cx set external "LIBRARY oodialog psp_setcx"

::attribute cy get external "LIBRARY oodialog psp_getcx"
::attribute cy set external "LIBRARY oodialog psp_setcx"

::attribute headerSubtitle get external "LIBRARY oodialog psp_getPageTitle"
::attribute headerSubtitle set external "LIBRARY oodialog psp_setPageTitle"

::attribute headerTitle get external "LIBRARY oodialog psp_getPageTitle"
::attribute headerTitle set external "LIBRARY oodialog psp_setPageTitle"

::attribute pageID get external "LIBRARY oodialog psp_pageID_atr"
::attribute pageNumber get external "LIBRARY oodialog psp_pageNumber_atr"

::attribute pageTitle get external "LIBRARY oodialog psp_getPageTitle"
::attribute pageTitle set external "LIBRARY oodialog psp_setPageTitle"

::attribute propSheet get unguarded external "LIBRARY oodialog psp_propSheet_atr"

::attribute resources get unguarded
::attribute resources set external "LIBRARY oodialog psp_setResources_atr"

::attribute tabIcon get unguarded
::attribute tabIcon set external "LIBRARY oodialog psp_setTabIcon_atr"

::attribute wantAccelerators get external "LIBRARY oodialog psp_getWantNotification"
::attribute wantAccelerators set external "LIBRARY oodialog psp_setWantNotification"

::attribute wantGetObject get external "LIBRARY oodialog psp_getWantNotification"
::attribute wantGetObject set external "LIBRARY oodialog psp_setWantNotification"

::attribute wasActivated get external "LIBRARY oodialog psp_wasActivated_atr"


::method endExecute unguarded                                                                   -- Not to be documented
    self~finished = .true
    self~stopIt
::method execute unguarded                                                                      -- Not to be documented
    self~initDialog
    if self~useStem then self~setDataStem(self~dlgData)
    else self~setData

    do while self~automaticMethods~Items > 0
        p = self~automaticMethods~pull
        m = self~automaticMethods~pull
        c = self~automaticMethods~pull
        o = c~new(p, self)
        o~start(m)
    end
::method init_propertySheetPage private external "LIBRARY oodialog psp_init_propertySheetPage"  -- Not to be documented
::method initTemplate external "LIBRARY oodialog psp_initTemplate"                              -- Not to be documented


::method apply unguarded
    use strict arg isOkButton, pageIndex, pageCurrent, psDlg

    ret = self~validate(isOkButton, psDlg)
    if ret == self~PSNRET_NOERROR then return self~applyNoError(psDlg)
    else return ret

::method applyNoError private unguarded                                          -- Document ??
    use strict arg psDlg

    self~initCode = 1

    if self~useStem then self~getDataStem(self~dlgData)
    self~getData

    psDlg~unchanged(self)
    return self~PSNRET_NOERROR

::method getObject unguarded
    return 0

::method help unguarded
    use strict arg psDlg
    return 0

::method killActive unguarded
    use strict arg psDlg
    return self~validatePage(psDlg)

::method pageCreate unguarded
    use strict arg psDlg
    return .true

::method queryCancel unguarded
    use strict arg psDlg
    self~initCode = 2
    return .true

::method queryFromSibling unguarded
    use strict arg arg1, arg2, psDlg
    return 0

::method queryInitialFocus unguarded
    use strict arg idDefFocus, psDlg
    return 0

::method reset unguarded
  use strict arg isCancelButton, psDlg
  self~initCode = 2
  return 0

::method setActive unguarded
    use strict arg psDlg
    return 0

::method setSize external "LIBRARY oodialog psp_setSize"
::method translateAccelerator unguarded
    use strict arg msg, keyCode, d, psDlg
    return self~PSNRET_NOERROR

::method wizBack unguarded
    use strict arg psDlg
    return 0

::method wizFinish unguarded
    use strict arg psDlg
    return 0

::method wizNext unguarded
    use strict arg psDlg
    return 0

::method validate private unguarded
    use strict arg isOkButton, psDlg
    return self~PSNRET_NOERROR

::method validatePage private unguarded
    use strict arg psDlg
    return .true


::class 'ResPSPDialog' public subclass ResDialog inherit PropertySheetPage

::method init external "LIBRARY oodialog respspdlg_init"

::method execute unguarded
    -- if autodetection is on, create the data attributes
    if self~autoDetect then do
       ids = self~getDataTableIDs
       do id over ids
          text = self~getControlText(id)
          self~addAttribute(id, text)
       end
    end
    forward class (.PropertySheetPage)

::method validate unguarded
    forward class (.PropertySheetPage)

-- Over-ride these methods with a do nothing so that the user can not start the dialog
::method popup unguarded
::method popupAsChild unguarded
::method executeAsync unguarded
::method endAsyncExecution unguarded



::class 'UserPSPDialog' public subclass UserDialog inherit PropertySheetPage

::method init external "LIBRARY oodialog userpspdlg_init"

::method execute unguarded
    forward class (.PropertySheetPage)

::method validate unguarded
    forward class (.PropertySheetPage)

-- Over-ride these methods with a do nothing so that the user can not start the dialog
::method popup unguarded
::method popupAsChild unguarded
::method executeAsync unguarded
::method endAsyncExecution unguarded


::class 'RcPSPDialog' public subclass UserDialog inherit PropertySheetPage

::method init external "LIBRARY oodialog rcpspdlg_init"
::method startTemplate external "LIBRARY oodialog rcpspdlg_startTemplate"

::method loadFrame private
  use strict arg expected
  return self~loadFrame:super(self~library, self~resourceID, "", expected)

::method loadItems private
  use strict arg opts
  return self~loadItems:super(self~library, self~resourceID, opts)

::method execute unguarded
    forward class (.PropertySheetPage)

::method validate unguarded
    forward class (.PropertySheetPage)

-- Over-ride these methods with a do nothing so that the user can not start the dialog
::method popup unguarded
::method popupAsChild unguarded
::method executeAsync unguarded
::method endAsyncExecution unguarded



/*            Owner and Control Dialogs                                       */

::class 'ResControlDialog' public subclass ResDialog inherit ControlDialog

::method startIt

   if self~startDialog(self~library, self~resourceID) then do
      -- if autodetection is on, create the data attributes
      if self~autoDetect then do
         ids = self~getDataTableIDs
         do id over ids
            text = self~getControlText(id)
            self~addAttribute(id, text)
         end
      end

      self~initDialog
      self~initializing = .false
      return .true
   end

   return .false

::method startDialog private external "LIBRARY oodialog resCtrlDlg_startDialog_pvt"


::method execute
    self~start("BEGINEXECUTION")
::method popup
    self~start("BEGINEXECUTION")
::method popupAsChild
    self~start("BEGINEXECUTION")
::method executeAsync abstract
::method endAsyncExecution abstract


::class 'UserControlDialog' public subclass UserDialog inherit ControlDialog

-- Over-ride the superclass startIt().  This is invoked from
-- ControlDialog::beginExecution.
::method startIt

    if self~basePtr = 0 then return .false

    if self~startChildDialog(self~basePtr, 0) == 0 then return .false

    self~initDialog
    self~initializing = .false;
    return .true


::method execute
    self~start("BEGINEXECUTION")
::method popup
    self~start("BEGINEXECUTION")
::method popupAsChild
    self~start("BEGINEXECUTION")
::method executeAsync abstract
::method endAsyncExecution abstract


::class 'RcControlDialog' subclass UserControlDialog public

::method init
    use strict arg rcFile, idDlg, initData. = .nil, includeFile = "", options = "", expected = 200, ownerData = .nil

    newArgs = .array~new(5)
    if arg(3, 'E') then newArgs[1] = arg(3)
    if arg(4, 'E') then newArgs[2] = arg(4)
    if arg(7, 'E') then newArgs[5] = arg(7)
    newArgs[3] = rcFile
    newArgs[4] = idDlg

    forward class (super) arguments (newArgs) continue
    if result <> 0 then return result

    self~extraOptions = options

    if \ self~isManaged then do
      self~initCode = self~load(rcFile, idDlg, options, expected)
    end

    return self~initCode

::method startTemplate external "LIBRARY oodialog rcCtrlDlg_startTemplate"

::method loadFrameRCCD
  use strict arg expected
  return self~loadFrame:super(self~library, self~resourceID, "", expected)

::method loadItemsRCCD
  use strict arg opts
  return self~loadItems:super(self~library, self~resourceID, opts)

::method execute
    self~start("BEGINEXECUTION")
::method popup
    self~start("BEGINEXECUTION")
::method popupAsChild
    self~start("BEGINEXECUTION")
::method executeAsync abstract
::method endAsyncExecution abstract


::class 'ControlDialog' mixinclass Object public

::attribute wasActivated get external "LIBRARY oodialog cd_get_wasActivated"

::method endExecution unguarded
    use strict arg isOkay = .false

    if isOkay, self~wasActivated then do
        self~initCode = 1
        if self~useStem then self~getDataStem(self~dlgData)
        self~getData
    end
    else do
        self~initCode = 2
    end
    self~finished = .true

    self~stopIt
    return self~initCode

::method initUpdateListView private
  use strict arg lvID, pause = .005

  self~addNewAttribute('updateListViewID', lvID, .true)

  src = .array~new
  src[1]  = "use strict arg hwnd"
  src[2]  = ""
  src[3]  = "lv = self~newListView(self~updateListViewID)"
  src[4]  = "if lv == .nil then return .false"
  src[5]  = ""
  src[6]  = "if hwnd == lv~hwnd then do"
  src[7]  = "  j = SysSleep("pause")"
  src[8]  = "  lv~redraw"
  src[9]  = "  return .true"
  src[10] = "end"
  src[11] = "return .false"
  self~setMethod('updateListView', src)

  owner = self~ownerDialog

  owner~addNewAttribute(updateListViewPageDialog, self, .true, .true)
  owner~addNewAttribute(updateListViewLastFocused, 0, .true, .true)

  src = .array~new
  src[1]  = "expose updateListViewPageDialog updateListViewLastFocused"
  src[2]  = "use arg flag, hwnd, hFocused, isMinimized"
  src[3]  = ""
  src[4]  = "reply .false"
  src[5]  = ""
  src[6]  = "if flag == INACTIVE then updateListViewLastFocused = hFocused"
  src[7]  = "else updateListViewPageDialog~updateListView(updateListViewLastFocused)"
  owner~addNewMethod('onUpdateListViewActivate', src, .true)

  owner~connectActivate('onUpdateListViewActivate')

/**   Do not document classes and methods from here to end of the file.
 *
 * Most of the classes will not be documented for 4.2.0 because they are not
 * ready.  They will be inlcuded in the release after 4.2.0.
 */


::method init class external "LIBRARY oodialog cd_init_cls"                                     -- Not to be documented

/*::attribute pageNumber get external "LIBRARY oodialog cd_get_pageNumber"
::attribute pageNumber set external "LIBRARY oodialog cd_set_pageNumber"*/

::attribute initializing get external "LIBRARY oodialog cd_get_initializing"
::attribute initializing set external "LIBRARY oodialog cd_set_initializing"

::attribute isManaged get external "LIBRARY oodialog cd_get_isManaged"

::attribute pageTitle get external "LIBRARY oodialog cd_get_pageTitle"
::attribute pageTitle set external "LIBRARY oodialog cd_set_pageTitle"

::attribute extraOptions get external "LIBRARY oodialog cd_get_extraOptions"
::attribute extraOptions set external "LIBRARY oodialog cd_set_extraOptions"

/*::attribute size get external "LIBRARY oodialog ctrlDlg_get_size"
::attribute size set external "LIBRARY oodialog ctrlDlg_set_size"

::attribute wantAllNotifications get external "LIBRARY oodialog ctrlDlg_get_wantAllNotifications"
::attribute wantAllNotifications set external "LIBRARY oodialog ctrlDlg_set_wantAllNotifications"

::attribute resources get unguarded
::attribute resources set external "LIBRARY oodialog psp_setResources_atr"

::attribute tabIcon get unguarded
::attribute tabIcon set external "LIBRARY oodialog psp_setTabIcon_atr"*/


::method controlDlgInit private external "LIBRARY oodialog cd_controlDlgInit"

::method beginExecution unguarded

    dlgData. = self~dlgData

    if \ self~isManaged then do
        if \ self~startIt then do
            self~finished = .true
            self~stopIt
            return 0
        end
    end

    if self~useStem then self~setDataStem(dlgData.)
    else self~setData

    do while self~automaticMethods~Items > 0
        p = self~automaticMethods~pull
        m = self~automaticMethods~pull
        c = self~automaticMethods~pull
        o = c~new(p, self)
        o~start(m)
    end

    self~waitForDialog

    return 0


-- Return .true, it's okay to leave the page, .false it is not okay, stay on the page
::method tabPageKillActive unguarded
  use strict arg owner, tab
  say "In ControlDialog::tabPageKillActive dlg:" self 'owner:' owner 'tab:' tab
  return .true

-- Return 0, accept the activation, otherwise page number of alternate page to set focus to.
::method tabPageSetActive unguarded
  use strict arg owner, tab
  say "In ControlDialog::tabPageSetActive dlg:" self 'owner:' owner 'tab:' tab
  return 0



::class 'TabOwnerDialog' mixinclass Object public

::method tabOwnerDlginit external "LIBRARY oodialog tod_tabOwnerDlgInit"
::method getTabPage external "LIBRARY oodialog tod_getTabPage"
::method tabOwnerOk external "LIBRARY oodialog tod_tabOwnerOk"
::method tabOwnerCancel external "LIBRARY oodialog tod_tabOwnerCancel"

-- Return .true, it's okay to leave the page, .false it is not okay, stay on the page
::method tabOwnerKillActive unguarded
  use strict arg pageDlg, tab
  say "In TabOwnerDialog::tabOwnerKillActive dlg:" self 'page:' pageDlg 'tab:' tab
  return .true

-- Return 0, accept the activation, otherwise page number of alternate page to set focus to.
::method tabOwnerSetActive unguarded
  use strict arg pageDlg, tab
  say "In TabOwnerDialog::tabOwnerSetActive dlg:" self 'page:' pageDlg 'tab:' tab
  return 0

::method tabOwnerSelChange unguarded
  use strict arg pageDlg, pageNumber
  return 0

::method tabOwnerSelChanging unguarded
  use strict arg pageDlg, pageNumber
  return 0


::class 'TabOwnerDlgInfo' subclass Object public

::method init external "LIBRARY oodialog todi_init"
::method add external "LIBRARY oodialog todi_add"


::class 'ManagedTab' subclass Object public

::method init external "LIBRARY oodialog mt_init"


::class 'ControlDlgInfo' subclass Object public

::attribute managed set external "LIBRARY oodialog cdi_set_managed"
::attribute title set external "LIBRARY oodialog cdi_set_title"
::attribute size set external "LIBRARY oodialog cdi_set_size"
::method init external "LIBRARY oodialog cdi_init"




/**
 * Windows Dialog Interface for Open Object Rexx (ooRexx.)
 *
 * Dialog Control Classes.
 */

-- Base class for all dialog controls
::class 'DialogControl' public inherit WindowBase WindowExtensions

::constant CCM_GETUNICODEFORMAT     "0x2006"
::constant CCM_GETVERSION           "0x2008"
::constant CCM_SETUNICODEFORMAT     "0x2005"
::constant CCM_SETVERSION           "0x2007"

::method new class external "LIBRARY oodialog dlgctrl_new_cls"
::method init class external "LIBRARY oodialog dlgctrl_init_cls"

::attribute id get unguarded    -- The numerical resource ID for this control
::attribute hDlg get unguarded  -- The window handle of that dialog
::attribute oDlg get unguarded  -- The ooRexx dialog object this control belongs to

::method init external "LIBRARY oodialog dlgctrl_init"
::method unInit external "LIBRARY oodialog dlgctrl_unInit"

::method addUserSubclass unguarded external "LIBRARY oodialog dlgctrl_addUserSubclass" -- Do not document for 4.2.0
::method assignFocus unguarded external "LIBRARY oodialog dlgctrl_assignFocus"
::method clearRect unguarded external "LIBRARY oodialog dlgctrl_clearRect"
::method connectCharEvent unguarded
  use strict arg methodName = 'onChar'
  return self~connectEvent('CHAR', methodName)

::method connectEvent unguarded external "LIBRARY oodialog dlgctrl_connectEvent"       -- Do not document for 4.2.0
::method connectFKeyPress unguarded external "LIBRARY oodialog dlgctrl_connectFKeyPress"
::method connectKeyPress unguarded external "LIBRARY oodialog dlgctrl_connectKeyPress"
::method data unguarded external "LIBRARY oodialog dlgctrl_data"
::method "data=" unguarded external "LIBRARY oodialog dlgctrl_dataEquals"
::method disconnectKeyPress unguarded external "LIBRARY oodialog dlgctrl_disconnectKeyPress"
::method hasKeyPressConnection unguarded external "LIBRARY oodialog dlgctrl_hasKeyPressConnection"
::method getTextSizeDlg unguarded external "LIBRARY oodialog dlgctrl_getTextSizeDlg"
::method group unguarded external "LIBRARY oodialog dlgctrl_tabGroup"
::method putInBag unguarded external "LIBRARY oodialog dlgctrl_putInBag"  -- Internal use only.
::method redrawRect unguarded external "LIBRARY oodialog dlgctrl_redrawRect"
::method setColor unguarded external "LIBRARY oodialog dlgctrl_setColor"
::method setParent unguarded external "LIBRARY oodialog dlgctrl_setParent"
::method setSysColor unguarded external "LIBRARY oodialog dlgctrl_setColor"
::method setWindowTheme unguarded external "LIBRARY oodialog dlgctrl_setWindowTheme"
::method tabStop unguarded external "LIBRARY oodialog dlgctrl_tabGroup"
::method textSize unguarded external "LIBRARY oodialog dlgctrl_textSize"
::method useUnicode unguarded
   use strict arg doUseUnicode
   return self~sendWinIntMsg(self~CCM_SETUNICODEFORMAT, doUseUnicode, 0)

::method useVersion unguarded
   use strict arg version
   return self~sendWinIntMsg(self~CCM_SETVERSION, version, 0)

::method usingUnicode unguarded
   use strict arg
   return (self~sendWinIntMsg(self~CCM_GETUNICODEFORMAT, 0, 0) <> 0)

::method usingVersion unguarded
   use strict arg
   return self~sendWinIntMsg(self~CCM_GETVERSION, 0, 0)

-- DEPRECATED START
::method captureMouse unguarded
   mouse = .Mouse~new(self)
   return mouse~capture

::method getFocus unguarded
   forward to (self~oDlg)

::method getMouseCapture unguarded
   use strict arg
   mouse = .Mouse~new(self)
   return mouse~getCapture

::method getTextSize unguarded
   forward message "getTextSizeDlg" continue
   return result~width result~height

::method isMouseButtonDown unguarded
   use strict arg whichButton = "LEFT"
   mouse = .Mouse~new(self)
   return mouse~isButtonDown(whichButton)

::method processMessage
   forward message "sendMessage"

::method releaseMouseCapture unguarded
   use strict arg
   mouse = .Mouse~new(self)
   return mouse~releaseCapture

::method setFocus unguarded
   forward to (self~oDlg)

::method tabToPrevious unguarded
   forward to (self~oDlg)

::method tabToNext unguarded
   forward to (self~oDlg)

::method value unguarded external "LIBRARY oodialog dlgctrl_data"
::method "value=" unguarded external "LIBRARY oodialog dlgctrl_dataEquals"
-- DEPRECATED END


/******** Button Classes ******************************************************/

::class 'ButtonControl' subclass DialogControl public
::class 'Button' subclass ButtonControl public

::constant BM_CLICK              "0x00F5"

::method click unguarded
   forward message "push"

::method getIdealSize unguarded external "LIBRARY oodialog bc_getIdealSize"
::method getImage unguarded external "LIBRARY oodialog bc_getImage"
::method getImageList unguarded external "LIBRARY oodialog bc_getImageList"
::method getTextMargin unguarded external "LIBRARY oodialog bc_getTextMargin"
::method push unguarded
   return self~sendWinIntMsg(self~BM_CLICK, 0, 0)

::method setImage unguarded external "LIBRARY oodialog bc_setImage"
::method setImageList unguarded external "LIBRARY oodialog bc_setImageList"
::method setTextMargin unguarded external "LIBRARY oodialog bc_setTextMargin"
::method state unguarded external "LIBRARY oodialog bc_getState"
::method "state=" unguarded external "LIBRARY oodialog bc_setState"
::method "style=" unguarded external "LIBRARY oodialog bc_setStyle"

-- Bitmap button methods ALL DEPRECATED.

-- Almost all the bitmap button methods were implemented in DialogExtensions.
-- The whole 'bitmap' button idea is antiquated, so the DialogExtensions methods
-- are documented, the button methods are deprecated and not documented.
::method changeBitmap unguarded
   arga = arg(1,"A")
   newarg = .array~new(arga~Items+1)
   newarg[1] = self~ID
   do i = 1 to arga~Items; if arga~hasindex(i) = 1 then newarg[i+1] = arga[i]; end
   forward to (self~oDlg) message "CHANGEBITMAPBUTTON" arguments (newarg)

::method dimBitmap unguarded
   arga = arg(1,"A")
   newarg = .array~new(arga~Items+1)
   newarg[1] = self~ID
   do i = 1 to arga~Items; if arga~hasindex(i) = 1 then newarg[i+1] = arga[i]; end
   forward to (self~oDlg) arguments (newarg)

::method displaceBitmap unguarded
   use strict arg x, y
   return self~oDlg~setBitmapPosition(self~ID, x, y)

::method drawBitmap unguarded
   arga = arg(1,"A")
   newarg = .array~new(arga~Items+2)
   newarg[1] = self~hwnd
   newarg[2] = self~id
   do i = 1 to arga~Items; if arga~hasindex(i) = 1 then newarg[i+2] = arga[i]; end
   forward to (self~oDlg) arguments (newarg)

::method getBitmapPosition unguarded
   use strict arg pos
   return self~oDlg~getBitmapPosition(self~ID, pos)

::method getBitmapSizeX unguarded
   return self~oDlg~getBitmapSizeX(self~ID)

::method getBitmapSizeY unguarded
   return self~oDlg~getBitmapSizeY(self~ID)

::method getBmpDisplacement unguarded
   return self~oDlg~getBmpDisplacement(self~ID)

::method scroll unguarded
   arga = arg(1,"A")
   newarg = .array~new(arga~Items+1)
   newarg[1] = self~ID
   do i = 1 to arga~Items; if arga~hasindex(i) = 1 then newarg[i+1] = arga[i]; end
   forward to (self~oDlg) message "SCROLLBUTTON" arguments (newarg)

::method scrollBitmapFromTo unguarded
   arga = arg(1,"A")
   newarg = .array~new(arga~Items+1)
   newarg[1] = self~id
   do i = 1 to arga~Items; if arga~hasindex(i) = 1 then newarg[i+1] = arga[i]; end
   forward to (self~oDlg) arguments (newarg)

::method scrollText unguarded
   arga = arg(1,"A")
   newarg = .array~new(arga~Items+1)
   newarg[1] = self~hwnd
   do i = 1 to arga~Items; if arga~hasindex(i) = 1 then newarg[i+1] = arga[i]; end
   forward to (self~oDlg) arguments (newarg)

::method setBitmapPosition unguarded
   use strict arg x, y = 0
   if arg(2, "E") then return self~oDlg~setBimapPosition(self~id, x, y)
   else return self~oDlg~setBimapPosition(self~id, x)

-- Bitmap button methods END ALL DEPRECATED.

/* For internal testing only, do not use this method */
::method test external "LIBRARY oodialog bc_test"
::method test class external "LIBRARY oodialog bc_test_cls"


::class 'RadioButton' subclass Button public
::method checkInGroup class external "LIBRARY oodialog rb_checkInGroup_cls"

::method check unguarded external "LIBRARY oodialog rb_check"
::method checked unguarded external "LIBRARY oodialog rb_checked"
::method getCheckState unguarded external "LIBRARY oodialog rb_getCheckState"
::method uncheck unguarded external "LIBRARY oodialog rb_uncheck"

-- DEPRECATED
::method isChecked external "LIBRARY oodialog rb_isChecked"

-- DEPRECATED
::method indeterminate external "LIBRARY oodialog rb_indeterminate"

::class 'CheckBox' subclass RadioButton public

::method isIndeterminate unguarded external "LIBRARY oodialog ckbx_isIndeterminate"
::method setIndeterminate unguarded external "LIBRARY oodialog ckbx_setIndeterminate"


/******** ComboBox Class ******************************************************/

::class 'ComboBox' subclass DialogControl public

::constant CB_SETEDITSEL               "0x0142"
::constant CB_DELETESTRING             "0x0144"
::constant CB_GETCOUNT                 "0x0146"
::constant CB_GETCURSEL                "0x0147"
::constant CB_RESETCONTENT             "0x014B"
::constant CB_SETCURSEL                "0x014E"
::constant CB_SHOWDROPDOWN             "0x014F"
::constant CB_GETDROPPEDSTATE          "0x0157"
::constant CB_GETTOPINDEX              "0x015b"
::constant CB_GETHORIZONTALEXTENT      "0x015d"
::constant CB_SETHORIZONTALEXTENT      "0x015e"

::method add unguarded external "LIBRARY oodialog cb_add"
::method addDirectory unguarded external "LIBRARY oodialog cb_addDirectory"
::method closeDropDown unguarded
   use strict arg
   return self~sendWinIntMsg(self~CB_SHOWDROPDOWN, 0, 0)

::method delete unguarded
   use strict arg index = (self~selectedIndex)
   ret = self~sendWinIntMsg(self~CB_DELETESTRING, index - 1, 0)
   if ret == 0 then self~deleteAll
   return ret

::method deleteAll unguarded
   use strict arg
   return self~sendWinIntMsg(self~CB_RESETCONTENT, 0, 0)

::method find unguarded external "LIBRARY oodialog cb_find"
::method getCue unguarded external "LIBRARY oodialog cb_getCue"
::method getComboBoxInfo unguarded external "LIBRARY oodialog cb_getComboBoxInfo"
::method getEditControl unguarded external "LIBRARY oodialog cb_getEditControl"
::method getFirstVisible unguarded
   return self~sendWinIntMsg(self~CB_GETTOPINDEX, 0, 0) + 1

::method getHorizontalExtent unguarded
   use strict arg
   return self~sendWinIntMsg(self~CB_GETHORIZONTALEXTENT, 0, 0)

::method getItemData unguarded external "LIBRARY oodialog cb_getItemData"
::method getItemHeight unguarded external "LIBRARY oodialog cb_getItemHeight"
::method getMinVisible unguarded external "LIBRARY oodialog cb_getMinVisible"
::method getText unguarded external "LIBRARY oodialog cb_getText"
::method insert unguarded external "LIBRARY oodialog cb_insert"
::method isDropDown unguarded external "LIBRARY oodialog cb_isDropDown"
::method isDropDownList unguarded external "LIBRARY oodialog cb_isDropDown"
::method isDropDownOpen unguarded
   use strict arg
   return self~sendWinIntMsg(self~CB_GETDROPPEDSTATE, 0, 0)

::method isGrandchild unguarded external "LIBRARY oodialog cb_isGrandchild"
::method isSimple unguarded external "LIBRARY oodialog cb_isDropDown"
::method items unguarded
   use strict arg
   return self~sendWinIntMsg(self~CB_GETCOUNT, 0, 0)

::method modify unguarded
   use strict arg index = (self~selectedIndex), newEntry
   if index <= 0 then return -1
   self~delete(index)
   return self~insert(index, newEntry)

::method openDropDown unguarded
   use strict arg
   return self~sendWinIntMsg(self~CB_SHOWDROPDOWN, 1, 0)

::method removeFullColor unguarded external "LIBRARY oodialog cb_removeFullColor"
::method removeItemData unguarded external "LIBRARY oodialog cb_removeItemData"
::method select unguarded external "LIBRARY oodialog cb_select"
::method selected unguarded
   use strict arg
   return self~getText(self~selectedIndex)

::method selectedIndex unguarded
   use strict arg
   return self~sendWinIntMsg(self~CB_GETCURSEL, 0, 0) + 1

::method selectIndex unguarded
   use strict arg ndx = 0
   ret = self~sendWinIntMsg(self~CB_SETCURSEL, ndx - 1, 0)
   if ret == -1, ndx <> 0 then return -1
   return ret + 1

::method setCue unguarded external "LIBRARY oodialog cb_setCue"
::method setEditSelection unguarded
   use strict arg startndx = 0, endndx = 0
   if endndx == 0 then endndx = -1
   lParam = .DlgUtil~makeLParam(startndx - 1, endndx)
   return self~sendWinIntMsg(self~CB_SETEDITSEL, 0, lParam) == -1

::method setFullColor unguarded external "LIBRARY oodialog cb_setFullColor"
::method setHorizontalExtent unguarded
   use strict arg extent
   self~sendWinIntMsg(self~CB_SETHORIZONTALEXTENT, extent, 0)
   return 0

::method setItemData unguarded external "LIBRARY oodialog cb_setItemData"
::method setItemHeight unguarded external "LIBRARY oodialog cb_setItemHeight"
::method setMinVisible unguarded external "LIBRARY oodialog cb_setMinVisible"

-- DEPRECATED
::method editSelection
   forward message "setEditSelection"



/******** DateTimePicker Class ************************************************/

::class 'DateTimePicker' subclass DialogControl public

::constant DTM_GETMCFONT           "0x100A"
::constant DTM_SETMCFONT           "0x1009"

::method closeMonthCal unguarded external "LIBRARY oodialog dtp_closeMonthCal"
::method getDateTime unguarded external "LIBRARY oodialog dtp_getDateTime"
::method getInfo unguarded external "LIBRARY oodialog dtp_getInfo"
::method getIdealSize unguarded external "LIBRARY oodialog dtp_getIdealSize"
::method getMonthCal unguarded external "LIBRARY oodialog dtp_getMonthCal"
::method getMonthCalColor unguarded external "LIBRARY oodialog dtp_getMonthCalColor"

::method getMonthCalFont unguarded
   use strict arg
   return self~sendWinIntMsgH(self~DTM_GETMCFONT, 0, 0)

::method getMonthCalStyle unguarded external "LIBRARY oodialog dtp_getMonthCalStyle"
::method getRange unguarded external "LIBRARY oodialog dtp_getRange"

::method setDateTime unguarded external "LIBRARY oodialog dtp_setDateTime"
::method setFormat unguarded external "LIBRARY oodialog dtp_setFormat"
::method setMonthCalColor unguarded external "LIBRARY oodialog dtp_setMonthCalColor"

::method setMonthCalFont unguarded
   use strict arg hFont, redraw = .true
   return self~sendWinHandleMsg(self~DTM_SETMCFONT, hFont, redraw)

::method setMonthCalStyle unguarded external "LIBRARY oodialog dtp_setMonthCalStyle"
::method setRange unguarded external "LIBRARY oodialog dtp_setRange"


/******** Edit Class **********************************************************/

::class 'EditControl' subclass DialogControl public
::class 'Edit' subclass EditControl public

::constant EM_SETSEL               "0x00B1"
::constant EM_SCROLL               "0x00B5"
::constant EM_LINESCROLL           "0x00B6"
::constant EM_SCROLLCARET          "0x00B7"
::constant EM_GETMODIFY            "0x00B8"
::constant EM_SETMODIFY            "0x00B9"
::constant EM_GETLINECOUNT         "0x00BA"
::constant EM_LINELENGTH           "0x00C1"
::constant EM_LIMITTEXT            "0x00C5"
::constant EM_CANUNDO              "0x00C6"
::constant EM_UNDO                 "0x00C7"
::constant EM_LINEFROMCHAR         "0x00C9"
::constant EM_SETTABSTOPS          "0x00CB"
::constant EM_SETPASSWORDCHAR      "0x00CC"
::constant EM_GETFIRSTVISIBLELINE  "0x00CE"
::constant EM_SETREADONLY          "0x00CF"
::constant EM_GETPASSWORDCHAR      "0x00D2"
::constant EM_SETMARGINS           "0x00D3"
::constant EM_GETMARGINS           "0x00D4"

::constant EM_NEGATIVEONE          4294967295

::constant EC_LEFTMARGIN           1       -- 0x0001
::constant EC_RIGHTMARGIN          2       -- 0x0002
::constant EC_USEFONTINFO          65535   -- 0xFFFF

::constant WM_CUT                  "0x0300"
::constant WM_COPY                 "0x0301"
::constant WM_PASTE                "0x0302"
::constant WM_CLEAR                "0x0303"

::attribute passwordChar unguarded set
    use strict arg char
    ch = char~c2d
    if self~isSingleLine, ch > 0, ch < 256 then self~sendWinIntMsg(self~EM_SETPASSWORDCHAR, ch, 0)

::attribute passwordChar unguarded get
    if \ self~isSingleLine then return ""
    char = self~sendWinIntMsg(self~EM_GETPASSWORDCHAR, 0, 0)
    if char \= 0 then return char~d2c
    else return ""

::method addStyle unguarded external "LIBRARY oodialog e_style"
::method canUndo unguarded
    use strict arg
    return self~sendWinIntMsg(self~EM_CANUNDO, 0, 0) != 0

::method clearText unguarded
    use strict arg
    self~sendWinIntMsg(self~WM_CLEAR, 0, 0)
    return 0

::method copyText unguarded
    use strict arg
    self~sendWinIntMsg(self~WM_COPY, 0, 0)
    return 0

::method cutText unguarded
    use strict arg
    self~sendWinIntMsg(self~WM_CUT, 0, 0)
    return 0

::method disableInternalResize unguarded
  use strict arg
  return self~connectEvent('WM_SIZE')

::method ensureCaretVisibility unguarded
    use strict arg
    self~sendWinIntMsg(self~EM_SCROLLCARET, 0, 0)
    return 0

::method firstVisibleLine unguarded
    use strict arg
    return self~sendWinIntMsg(self~EM_GETFIRSTVISIBLELINE, 0, 0) + 1

::method getCue unguarded external "LIBRARY oodialog e_getCue"
::method getLine unguarded external "LIBRARY oodialog e_getLine"
::method getMargins unguarded
    use strict arg
    marg = self~sendWinIntMsg(self~EM_GETMARGINS, 0, 0)
    m = .directory~new
    m~right = .DlgUtil~hiWord(marg)
    m~left = .DlgUtil~loWord(marg)
    return m

::method getRect unguarded external "LIBRARY oodialog e_getRect"
::method getStyle unguarded external "LIBRARY oodialog e_style"
::method hideBalloon unguarded external "LIBRARY oodialog e_hideBallon"
::method isGrandChild unguarded external "LIBRARY oodialog e_isGrandchild"
::method isModified unguarded
    use strict arg
    return self~sendWinIntMsg(self~EM_GETMODIFY, 0, 0) <> 0

::method isSingleLine unguarded external "LIBRARY oodialog e_isSingleLine"
::method lineScroll unguarded
    use strict arg cx, cy
    if self~isSingleLine then return 1
    self~sendWinIntMsg(self~EM_LINESCROLL, cx, cy)
    return 0

::method lineFromIndex unguarded external "LIBRARY oodialog e_lineFromIndex"
::method lineIndex unguarded external "LIBRARY oodialog e_lineIndex"
::method lineLength unguarded external "LIBRARY oodialog e_lineLength"
::method lines unguarded
    use strict arg
    return self~sendWinIntMsg(self~EM_GETLINECOUNT, 0, 0)

::method margins unguarded
    m = self~getMargins
    return m~left m~right

::method noContextMenu unguarded
  use strict arg
  return self~connectEvent('CONTEXTMENU')

::method pasteText unguarded
    use strict arg
    self~sendWinIntMsg(self~WM_PASTE, 0, 0)
    return 0

::method removeStyle unguarded external "LIBRARY oodialog e_style"
::method replaceSelText unguarded external "LIBRARY oodialog e_replaceSelText"
::method replaceStyle unguarded external "LIBRARY oodialog e_style"
::method scrollCommand unguarded
    use arg kind = "UP", reps = 1
    kind = kind~translate
    if self~isSingleLine then return 0
    select
        when kind = "UP" | kind = "LEFT" then wParam = 0
        when kind = "DOWN" | kind = "RIGHT" then wParam = 1
        when kind = "PAGEUP" | kind = "PAGELEFT" then wParam = 2
        when kind = "PAGEDOWN" | kind = "PAGERIGHT" then wParam = 3
        otherwise wParam = 0
    end
    do i = 1 to reps
        ret = self~sendWinIntMsg(self~EM_SCROLL, wParam, 0)
    end
    return ret

::method select unguarded
    use strict arg start = 1, end = 0
    self~sendWinIntMsg(self~EM_SETSEL, start - 1, end - 1)
    return 0

::method selected unguarded
    s = self~selection
    return s~startChar s~endChar

::method selection unguarded external "LIBRARY oodialog e_selection"
::method setCue unguarded external "LIBRARY oodialog e_setCue"
::method setLimit unguarded
    use strict arg limit
    self~sendWinUintMsg(self~EM_LIMITTEXT, limit, 0)
    return 0

::method setMargins unguarded
    use arg left, right
    if arg(1, 'O'), arg(2, 'O') then do
       self~sendWinIntMsg(self~EM_SETMARGINS, 0, self~EC_USEFONTINFO)
    end
    else do
       flag = 0
       if arg(1, 'E') then flag = self~EC_LEFTMARGIN
       if arg(2, 'E') then flag = .DlgUtil~or(flag, self~EC_RIGHTMARGIN)
       lParam = .DlgUtil~makeLParam(left, right)
       self~sendWinIntMsg(self~EM_SETMARGINS, flag, lParam)
    end
    return 0

::method setModified unguarded
    use strict arg bool = .true
    self~sendWinIntMsg(self~EM_SETMODIFY, bool, 0)
    return 0

::method setReadOnly unguarded
    use strict arg bool = .true
    return self~sendWinIntMsg(self~EM_SETREADONLY, bool, 0) <> 0

::method setRect unguarded external "LIBRARY oodialog e_setRect"
::method setTabStops unguarded external "LIBRARY oodialog e_setTabStops"
::method showBalloon unguarded external "LIBRARY oodialog e_showBallon"

::method "tab=" unguarded
    use strict arg dlgunits
    self~setTabStops(.array~of(dlgunits))

::method undo unguarded
    use strict arg
    return self~sendWinIntMsg(self~EM_UNDO, 0, 0) != 0

::method wantReturn unguarded
  use strict arg mthName = 'onReturn'
  return self~connectEvent('WANTRETURN', mthName)



/******** GroupBox Class ******************************************************/

::class 'GroupBox' subclass DialogControl public
::method "style=" unguarded external "LIBRARY oodialog gb_setStyle"


/******** ListBox Class *******************************************************/

::class 'ListBox' subclass DialogControl public

::constant LB_DELETESTRING         "0x0182"
::constant LB_RESETCONTENT         "0x0184"
::constant LB_SETCURSEL            "0x0186"
::constant LB_GETCURSEL            "0x0188"
::constant LB_GETCOUNT             "0x018B"
::constant LB_GETTOPINDEX          "0x018E"
::constant LB_GETSELCOUNT          "0x0190"
::constant LB_GETHORIZONTALEXTENT  "0x0193"
::constant LB_SETHORIZONTALEXTENT  "0x0194"
::constant LB_SETCOLUMNWIDTH       "0x0195"
::constant LB_SETTOPINDEX          "0x0197"
::constant LB_SELITEMRANGE         "0x019B"
::constant LB_SETITEMHEIGHT        "0x01A0"
::constant LB_GETITEMHEIGHT        "0x01A1"

::method add unguarded external "LIBRARY oodialog lb_add"
::method addDirectory unguarded external "LIBRARY oodialog lb_addDirectory"
::method "columnWidth=" unguarded -- Dialog units, not accurate
   use strict arg dlgunits
   if dlgunits~datatype("N") = 0 then return
   self~columnWidthPx = trunc(dlgunits * self~factorX)

::method "columnWidthPx=" unguarded
   use strict arg pixels
   self~sendWinIntMsg(self~LB_SETCOLUMNWIDTH, pixels, 0)

::method delete unguarded
   use strict arg index = (self~selectedIndex)
   if index == 0 then return -1
   return self~sendWinIntMsg(self~LB_DELETESTRING, index - 1, 0)

::method deleteAll unguarded
   self~sendWinIntMsg(self~LB_RESETCONTENT, 0, 0)
   return 0

::method deSelectIndex unguarded external "LIBRARY oodialog lb_deselectIndex"
::method deselectRange unguarded
   use strict arg fromNdx = 1, toNdx = (self~items)
   if self~isSingleSelection then return -1
   lParam = .DlgUtil~makeLParam(fromNdx - 1, toNdx - 1)
   return self~sendWinIntMsg(self~LB_SELITEMRANGE, .false, lParam)

::method find unguarded external "LIBRARY oodialog lb_find"
::method getFirstVisible unguarded
   return self~sendWinIntMsg(self~LB_GETTOPINDEX, 0, 0) + 1

::method getText unguarded external "LIBRARY oodialog lb_getText"
::method hitTestInfo unguarded external "LIBRARY oodialog lb_hitTestInfo"
::method insert unguarded external "LIBRARY oodialog lb_insert"
::method isSingleSelection unguarded external "LIBRARY oodialog lb_isSingleSelection"
::method itemHeight unguarded     -- Dialog units, not accurate
   return self~itemHeightPx / self~factorY

::method "itemHeight=" unguarded  -- Dialog units, not accurate
   use strict arg dlgunits
   if dlgunits~datatype("N") = 0 then return
   self~itemHeightPx = trunc(dlgunits * self~factorY)

::method itemHeightPx unguarded
   return self~sendWinIntMsg(self~LB_GETITEMHEIGHT, 0, 0)

::method "itemHeightPx=" unguarded
   use strict arg pixels
   self~sendWinIntMsg(self~LB_SETITEMHEIGHT, pixels, 0)

::method items unguarded
   return self~sendWinIntMsg(self~LB_GETCOUNT, 0, 0)

::method makeFirstVisible unguarded
   use strict arg ndx = 1
   return self~sendWinIntMsg(self~LB_SETTOPINDEX, ndx - 1, 0)

::method modify unguarded
   use strict arg index = (self~selectedIndex), newItem
   if index <= 0 then return -1
   self~delete(index)
   return self~insert(index, newItem)

::method select unguarded external "LIBRARY oodialog lb_select"
::method selected unguarded
   return self~getText(self~selectedIndex)

::method selectedIndex unguarded external "LIBRARY oodialog lb_selectedIndex"
::method selectedItems unguarded
   return self~sendWinIntMsg(self~LB_GETSELCOUNT, 0, 0)

::method selectIndex unguarded external "LIBRARY oodialog lb_selectIndex"
::method selectedIndexes unguarded                                    -- TODO be nice to return an array
   return self~oDlg~getListBoxData(self~id)

::method selectRange unguarded
   use strict arg fromNdx = 1, toNdx = (self~items)
   if self~isSingleSelection then return -1
   lParam = .DlgUtil~makeLParam(fromNdx - 1, toNdx - 1)
   return self~sendWinIntMsg(self~LB_SELITEMRANGE, .true, lParam)

::method setTabulators unguarded external "LIBRARY oodialog generic_setListTabulators"
::method setWidth unguarded       -- Dialog units, not accurate
   use strict arg dlgunits
   if dlgunits~datatype("N") = 0 then return -1
   px = trunc(dlgunits * self~factorX)
   self~setWidthPx(px)

::method setWidthPx unguarded
   use strict arg pixels
   self~sendWinIntMsg(self~LB_SETHORIZONTALEXTENT, pixels, 0)
   return 0

::method width unguarded          -- Dialog units, not accurate
   return self~widthPx / self~factorX

::method widthPx unguarded
   return self~sendWinIntMsg(self~LB_GETHORIZONTALEXTENT, 0, 0)



/******** MonthCalendar Class *************************************************/

::class 'MonthCalendar' subclass DialogControl public

::constant MCM_GETMAXSELCOUNT      "0x1003"
::constant MCM_SETMAXSELCOUNT      "0x1004"
::constant MCM_GETMAXTODAYWIDTH    "0x1015"
::constant MCM_GETMONTHDELTA       "0x1013"
::constant MCM_SETMONTHDELTA       "0x1014"

::attribute date unguarded external "LIBRARY oodialog _mc_date"

::method addStyle unguarded external "LIBRARY oodialog mc_addRemoveStyle"
::method getCalendarBorder unguarded external "LIBRARY oodialog mc_getCalendarBorder"
::method getCalendarCount unguarded external "LIBRARY oodialog mc_getCalendarCount"
::method getCALID unguarded external "LIBRARY oodialog mc_getCALID"
::method getColor unguarded external "LIBRARY oodialog mc_getColor"
::method getCurrentView unguarded external "LIBRARY oodialog mc_getCurrentView"
::method getFirstDayOfWeek unguarded external "LIBRARY oodialog mc_getFirstDayOfWeek"
::method getGridInfo unguarded external "LIBRARY oodialog mc_getGridInfo"
::method getMaxSelection unguarded
   use strict arg
   return self~sendWinIntMsg(self~MCM_GETMAXSELCOUNT, 0, 0)

::method getMaxTodayWidth unguarded
   use strict arg
   return self~sendWinIntMsg(self~MCM_GETMAXTODAYWIDTH, 0, 0)

::method getMinRect unguarded external "LIBRARY oodialog mc_getMinRect"
::method getMonthDelta unguarded
   use strict arg
   return self~sendWinIntMsg(self~MCM_GETMONTHDELTA, 0, 0)

::method getMonthRange unguarded external "LIBRARY oodialog mc_getMonthRange"
::method getRange unguarded external "LIBRARY oodialog mc_getRange"
::method getSelectionRange unguarded external "LIBRARY oodialog mc_getSelectionRange"
::method getStyle unguarded external "LIBRARY oodialog mc_getStyle"
::method getToday unguarded external "LIBRARY oodialog mc_getToday"
::method hitTest unguarded external "LIBRARY oodialog mc_hitTestInfo"  -- Error in 4.2.0 docs, name should have been hitTestInfo. Need to keep for backwards compatibility
::method hitTestInfo unguarded external "LIBRARY oodialog mc_hitTestInfo"
::method removeStyle unguarded external "LIBRARY oodialog mc_addRemoveStyle"
::method replaceStyle unguarded external "LIBRARY oodialog mc_replaceStyle"
::method setCalendarBorder unguarded external "LIBRARY oodialog mc_setCalendarBorder"
::method setCALID unguarded external "LIBRARY oodialog mc_setCALID"
::method setColor unguarded external "LIBRARY oodialog mc_setColor"
::method setCurrentView unguarded external "LIBRARY oodialog mc_setCurrentView"
::method setDayState unguarded external "LIBRARY oodialog mc_setDayState"
::method setDayStateQuick unguarded external "LIBRARY oodialog mc_setDayStateQuick"
::method setFirstDayOfWeek unguarded external "LIBRARY oodialog mc_setFirstDayOfWeek"
::method setMaxSelection unguarded
   use strict arg count
   return self~sendWinIntMsg(self~MCM_SETMAXSELCOUNT, count, 0) <> 0

::method setMonthDelta unguarded
   use strict arg amount
   return self~sendWinIntMsg(self~MCM_SETMAXTODAYWIDTH, amount, 0)

::method setRange unguarded external "LIBRARY oodialog mc_setRange"
::method setSelectionRange unguarded external "LIBRARY oodialog mc_setSelectionRange"
::method setToday unguarded external "LIBRARY oodialog mc_setToday"
::method sizeRectToMin unguarded external "LIBRARY oodialog mc_sizeRectToMin"


/******** ProgressBar Class ***************************************************/

::class 'ProgressBar' subclass DialogControl public

-- WM_USER == 0x400 -> 1024
::constant PBM_SETPOS          "0x0402"
::constant PBM_DELTAPOS        "0x0403"
::constant PBM_SETSTEP         "0x0404"
::constant PBM_STEPIT          "0x0405"
::constant PBM_GETPOS          "0x0408"
::constant PBM_SETBARCOLOR     "0x0409"
::constant PBM_SETBKCOLOR      "0x2001"

::method backgroundColor unguarded
   use strict arg newColor
   return self~sendWinUintMsg(self~PBM_SETBKCOLOR, 0, newColor)

::method barColor unguarded
   use strict arg newColor
   return self~sendWinUintMsg(self~PBM_SETBARCOLOR, 0, newColor)

::method getFullRange unguarded external "LIBRARY oodialog pbc_getFullRange"
::method getPos unguarded
   use strict arg
   return self~sendWinIntMsg(self~PBM_GETPOS, 0, 0)

::method setFullRange unguarded external "LIBRARY oodialog pbc_setFullRange"
::method setMarquee unguarded external "LIBRARY oodialog pbc_setMarquee"
::method setPos unguarded
   use strict arg position
   return self~sendWinIntMsg(self~PBM_SETPOS, position, 0)

::method setStep unguarded
  use strict arg newStep = 10
   return self~sendWinIntMsg(self~PBM_SETSTEP, newStep, 0)

::method step unguarded
   use strict arg delta = 0
   msg = self~PBM_STEPIT
   if arg(1, 'E') then msg = self~PBM_DELTAPOS
   return self~sendWinIntMsg(msg, delta, 0)


-- DEPRECATED
::method getRange unguarded external "LIBRARY oodialog pbc_getFullRange"
::method setRange unguarded
   forward message "setFullRange" continue
   return result~min result~max



/******** ScrollBar Class *****************************************************/


::class 'ScrollBar' subclass DialogControl public

::constant LINEUP           0
::constant LINELEFT         0
::constant LINEDOWN         1
::constant LINERIGHT        1
::constant PAGEUP           2
::constant PAGELEFT         2
::constant PAGEDOWN         3
::constant PAGERIGHT        3
::constant THUMBPOSITION    4
::constant THUMBTRACK       5
::constant TOP              6
::constant LEFT             6
::constant BOTTOM           7
::constant RIGHT            7
::constant ENDSCROLL        8

::method determinePosition unguarded
   use strict arg posdata, single = 1, page = 10
   code = .DlgUtil~loWord(posdata)
   pos = self~getPos
   r = self~getRange
   if .SystemErrorCode <> 0 then return pos -- getRange failed

   select
      /* Line up */
      when code == self~LINEUP then pos = max(r~min, pos - single)
      /* Line down */
      when code == self~LINEDOWN then pos = min(r~max, pos + single)
      /* page up */
      when code == self~PAGEUP then pos = max(r~min, pos - page)
      /* page down */
      when code == self~PAGEDOWN then pos = min(r~max, pos + page)
      /* track position */
      when code == self~THUMBPOSITION then pos = .DlgUtil~hiWord(posdata)
      /* tracking */
      when code == self~THUMBTRACK then pos = .DlgUtil~loWord(posdata)
      /* top */
      when code == self~TOP then pos = r~min
      /* bottom */
      when code == self~BOTTOM then pos = r~max
      otherwise nop;
   end
   self~setPos(pos)
   return pos

::method getPos unguarded external "LIBRARY oodialog sb_getPosition"
::method getRange unguarded external "LIBRARY oodialog sb_getRange"
::method position unguarded external "LIBRARY oodialog sb_getPosition"
::method range unguarded
   r = self~getRange
   return r~min r~max

::method setPos unguarded external "LIBRARY oodialog sb_setPosition"
::method setRange unguarded external "LIBRARY oodialog sb_setRange"



/******** Static Class ********************************************************/

::class 'StaticControl' subclass DialogControl public
::class 'Static' subclass StaticControl public

::method getIcon unguarded external "LIBRARY oodialog stc_getIcon"
::method setIcon unguarded external "LIBRARY oodialog stc_setIcon"
::method getImage unguarded external "LIBRARY oodialog stc_getImage"
::method setImage unguarded external "LIBRARY oodialog stc_setImage"


/******** TrackBar Class ******************************************************/

::class 'SliderControl' subclass DialogControl public
::class 'TrackBar' subclass SliderControl public

-- TB_xx event notification reason codes
::constant UP                   0
::constant DOWN                 1
::constant PAGEUP               2
::constant PAGEDOWN             3
::constant POSITION             4
::constant DRAG                 5
::constant TOP                  6
::constant BOTTOM               7
::constant ENDTRACK             8

-- TBM_ messages are defined as WM_USER + x
-- WM_USER == 0x0400

::constant TBM_GETPOS              "0x0400"
::constant TBM_GETRANGEMIN         "0x0401"
::constant TBM_GETRANGEMAX         "0x0402"
::constant TBM_GETTIC              "0x0403"
::constant TBM_SETTIC              "0x0404"
::constant TBM_SETPOS              "0x0405"
::constant TBM_SETRANGE            "0x0406"
::constant TBM_SETRANGEMIN         "0x0407"
::constant TBM_SETRANGEMAX         "0x0408"
::constant TBM_CLEARTICS           "0x0409"
::constant TBM_SETSEL              "0x040A"
::constant TBM_SETSELSTART         "0x040B"
::constant TBM_SETSELEND           "0x040C"
::constant TBM_GETNUMTICS          "0x0410"
::constant TBM_GETSELSTART         "0x0411"
::constant TBM_GETSELEND           "0x0412"
::constant TBM_CLEARSEL            "0x0413"
::constant TBM_SETTICFREQ          "0x0414"
::constant TBM_SETPAGESIZE         "0x0415"
::constant TBM_GETPAGESIZE         "0x0416"
::constant TBM_SETLINESIZE         "0x0417"
::constant TBM_GETLINESIZE         "0x0418"

::method clearSelRange unguarded
   use strict arg redraw = .true
   self~sendWinIntMsg(self~TBM_CLEARSEL, redraw, 0)
   return 0

::method clearTicks unguarded
   use strict arg redraw = .true
   self~sendWinIntMsg(self~TBM_CLEARTICS, redraw, 0)
   return 0

::method countTicks unguarded
   return self~sendWinIntMsg(self~TBM_GETNUMTICS, 0, 0)

::method getLineStep unguarded
   return self~sendWinIntMsg(self~TBM_GETLINESIZE, 0, 0)

::method getMax unguarded
   return self~sendWinIntMsg(self~TBM_GETRANGEMAX, 0, 0)

::method getMin unguarded
   use strict arg
   return self~sendWinIntMsg(self~TBM_GETRANGEMIN, 0, 0)

::method getPageStep unguarded
   return self~sendWinIntMsg(self~TBM_GETPAGESIZE, 0, 0)

::method getRange unguarded external "LIBRARY oodialog trckbar_getRange"
::method getSelEnd unguarded
   use strict arg
   return self~sendWinIntMsg(self~TBM_GETSELEND, 0, 0)

::method getSelRange unguarded external "LIBRARY oodialog trckbar_getSelRange"
::method getSelStart unguarded
   use strict arg
   return self~sendWinIntMsg(self~TBM_GETSELSTART, 0, 0)

::method getTick unguarded
   use strict arg tic
   return self~sendWinIntMsg(self~TBM_GETTIC, tic, 0)

::method initRange unguarded
   use strict arg min = 0, max = 100, redraw = .false
   if max < min then return -1
   self~sendWinIntMsg(self~TBM_SETRANGE, redraw, .DlgUtil~makeLParam(min, max))
   return 0

::method initSelRange unguarded
   use strict arg min = 0, max = (self~getMax), redraw = .false
   if max < min then return -1
   self~sendWinIntMsg(self~TBM_SETSEL, redraw, .DlgUtil~makeLParam(min, max))
   return 0

::method pos unguarded
   use strict arg
   return self~sendWinIntMsg(self~TBM_GETPOS, 0, 0)

::method "pos=" unguarded
   forward message "setPos"

::method range unguarded
   r = self~getRange
   return r~min r~max

::method selRange
   sr = self~getSelRange
   return sr~start sr~end

::method setSelEnd unguarded
   use strict arg max, redraw = .true
   self~sendWinIntMsg(self~TBM_SETSELEND, redraw, min)
   return 0

::method setLineStep unguarded
   use strict arg step
   return self~sendWinIntMsg(self~TBM_SETLINESIZE, 0, step)

::method setMax unguarded
   use strict arg max, redraw = .true
   self~sendWinIntMsg(self~TBM_SETRANGEMAX, redraw, max)
   return 0

::method setMin unguarded
   use strict arg min, redraw = .true
   self~sendWinIntMsg(self~TBM_SETRANGEMIN, redraw, min)
   return 0

::method setPageStep unguarded
   use strict arg step
   return self~sendWinIntMsg(self~TBM_SETPAGESIZE, 0, step)

::method setPos unguarded
   use strict arg p, redraw = .false
   self~sendWinIntMsg(self~TBM_SETPOS, redraw, p)
   return 0

::method setSelStart unguarded
   use strict arg min, redraw = .true
   self~sendWinIntMsg(self~TBM_SETSELSTART, redraw, min)
   return 0

::method setTickAt unguarded
   use strict arg pos
   return self~sendWinIntMsg(self~TBM_SETTIC, 0, pos)

::method setTickFrequency unguarded
   use strict arg freq
   return self~sendWinIntMsg(self~TBM_SETTICFREQ, freq, 0)



/******** Tab Class & Releated ************************************************/

::class 'OwnedTabInfo' subclass Object public

::attribute nID
::attribute pages
::attribute sID
::attribute tab

::method init
  use strict arg id, pages = (.array~new)

::class 'TabControl' subclass DialogControl public
::class 'Tab' subclass TabControl public

-- TCM_FIRST == 0x1300  4864
::constant TCM_GETITEMCOUNT    "0x1304"
::constant TCM_GETROWCOUNT     "0x132C"
::constant TCM_GETCURSEL       "0x130B"
::constant TCM_SETCURSEL       "0x130C"
::constant TCM_SETCURFOCUS     "0x1330"
::constant TCM_GETCURFOCUS     "0x132F"
::constant TCM_DELETEALLITEMS  "0x1309"
::constant TCM_DELETEITEM      "0x1308"
::constant TCM_SETMINTABWIDTH  "0x1331"

::method addFullSeq unguarded external "LIBRARY oodialog tab_addFullSeq"
::method addSequence unguarded external "LIBRARY oodialog tab_addSequence"

-- adjustToRectangle() and requiredWindowSize() are the old methods.  This set
-- up produces the same results as the code did, which seems to be opposite of
-- what the doc says.
--
-- calcWindowRect() and calcDisplayRect() are named and documented according to
-- MSDN documentation.  (Which could be wrong.)

::method adjustToRectangle unguarded
   use strict arg left, top, right, bottom
   r = .Rect~new(left, top, right, bottom)
   self~calcWindowRect(r)
   return r~left r~top r~right r~bottom

::method calcDisplayRect unguarded external "LIBRARY oodialog tab_calcRect"
::method calcWindowRect unguarded external "LIBRARY oodialog tab_calcRect"
::method delete unguarded
   use strict arg item
   ret = self~sendWinIntMsg(self~TCM_DELETEITEM, item, 0)
   return ret == 0

::method deleteAll unguarded
   use strict arg
   ret = self~sendWinIntMsg(self~TCM_DELETEALLITEMS, 0, 0)
   return ret == 0

::method focus unguarded
   use strict arg item
   self~sendWinIntMsg(self~TCM_SETCURFOCUS, item, 0)
   return 0

::method focused unguarded
   use strict arg
   return self~sendWinIntMsg(self~TCM_GETCURFOCUS, 0, 0)

::method getImageList unguarded external "LIBRARY oodialog tab_getImageList"
::method getItemRect unguarded external "LIBRARY oodialog tab_getItemRect"
::method insert unguarded external "LIBRARY oodialog tab_insert"
::method itemInfo unguarded external "LIBRARY oodialog tab_itemInfo"
::method items unguarded
   use strict arg
   return self~sendWinIntMsg(self~TCM_GETITEMCOUNT, 0, 0)

::method last unguarded
   use strict arg
   return self~items - 1

::method modify unguarded external "LIBRARY oodialog tab_modify"
::method posRectangle unguarded
   use strict arg item
   r = .Rect~new
   if self~getItemRect(item, r) then return r~top r~left r~bottom r~right
   else return ""

::method requiredWindowSize unguarded
   use strict arg left, top, right, bottom
   r = .Rect~new(left, top, right, bottom)
   self~calcDisplayRect(r)
   return r~left r~top r~right r~bottom

::method rows unguarded
   use strict arg
   return self~sendWinIntMsg(self~TCM_GETROWCOUNT, 0, 0)

::method select unguarded external "LIBRARY oodialog tab_select"
::method selected unguarded external "LIBRARY oodialog tab_selected"
::method selectedIndex unguarded
   use strict arg
   return self~sendWinIntMsg(self~TCM_GETCURSEL, 0, 0)

::method selectIndex unguarded
   use strict arg item
   return self~sendWinIntMsg(self~TCM_SETCURSEL, item, 0)

::method setImageList unguarded external "LIBRARY oodialog tab_setImageList"
::method setItemSize unguarded external "LIBRARY oodialog tab_setItemSize"
::method setMinTabWidth unguarded
   use strict arg width
   return self~sendWinIntMsg(self~TCM_SETMINTABWIDTH, 0, width)

::method setPadding unguarded external "LIBRARY oodialog tab_setPadding"

::method setSize unguarded
   forward message "setItemSize" continue
   return result~width result~height

-- DEPRECATED
::method removeImages unguarded
   return self~setImageList(.nil)

-- DEPRECATED
::method setImages unguarded external "LIBRARY oodialog tab_setImageList"



/******** UPDown Class ********************************************************/

::class 'UpDown' subclass DialogControl public

::constant UDM_SETBASE             "0x046D"
::constant UDM_GETBASE             "0x046E"
::constant UDM_SETPOS32            "0x0471"

::method deltaPosReply class external "LIBRARY oodialog ud_deltaPosReply_cls"

::method getAcceleration unguarded external "LIBRARY oodialog ud_getAcceleration"
::method getBase unguarded
   use strict arg
   return self~sendWinIntMsg(self~UDM_GETBASE, 0, 0)

::method getBuddy unguarded external "LIBRARY oodialog ud_getBuddy"
::method getRange unguarded external "LIBRARY oodialog ud_getRange"
::method getPosition unguarded external "LIBRARY oodialog ud_getPosition"
::method setAcceleration unguarded external "LIBRARY oodialog ud_setAcceleration"
::method setBase unguarded
   use strict arg newBase
   return self~sendWinIntMsg(self~UDM_SETBASE, newBase, 0)

::method setBuddy unguarded external "LIBRARY oodialog ud_setBuddy"
::method setPosition unguarded
   use strict arg newPos
   return self~sendWinIntMsg(self~UDM_SETPOS32, 0, newPos)

::method setRange unguarded external "LIBRARY oodialog ud_setRange"

/**
 * Windows Dialog Interface for Open Object Rexx (ooRexx.)
 *
 * ListView and list-view helper Classes.
 */

::class 'ListControl' subclass DialogControl public
::class 'ListView' subclass ListControl public

-- LVM_FIRST = 0x1000  == 4096
::constant LVM_GETCOLUMNWIDTH     "0x101D"
::constant LVM_SETHOVERTIME       "0x1047"
::constant LVM_GETHOVERTIME       "0x1048"
::constant LVM_DELETECOLUMN       "0x101C"
::constant LVM_GETITEMSPACING     "0x1033"
::constant LVM_SETITEMCOUNT       "0x102F"
::constant LVM_SCROLL             "0x1014"
::constant LVM_GETCOUNTPERPAGE    "0x1028"
::constant LVM_ENSUREVISIBLE      "0x1013"
::constant LVM_UPDATE             "0x102A"
::constant LVM_REDRAWITEMS        "0x1015"
::constant LVM_GETSELECTEDCOUNT   "0x1032"
::constant LVM_GETITEMCOUNT       "0x1004"
::constant LVM_EDITLABELA         "0x1017"
::constant LVM_EDITLABELW         "0x1076"
::constant LVM_GETTOPINDEX        "0x1027"

::constant IMAGECALLBACK          -1
::constant IMAGENONE              -2
::constant GROUPIDCALLBACK        -1
::constant GROUPIDNONE            -2

::constant LVCFMT_LINE_BREAK          1048576   -- 0x100000
::constant LVCFMT_FILL                2097152   -- 0x200000
::constant LVCFMT_WRAP                4194304   -- 0x400000
::constant LVCFMT_NO_TITLE            8388608   -- 0x800000
::constant LVCFMT_TILE_PLACEMENTMASK  3145728   -- (LVCFMT_LINE_BREAK | LVCFMT_FILL)

::method add unguarded external "LIBRARY oodialog lv_add"
::method addExtendedStyle unguarded external "LIBRARY oodialog lv_addClearExtendStyle"
::method addFullRow unguarded external "LIBRARY oodialog lv_addFullRow"
::method addRow unguarded external "LIBRARY oodialog lv_addRow"
::method addRowFromArray unguarded external "LIBRARY oodialog lv_addRowFromArray"
::method addStyle unguarded external "LIBRARY oodialog lv_addRemoveStyle"
::method alignLeft unguarded external "LIBRARY oodialog lv_arrange"
::method alignTop unguarded external "LIBRARY oodialog lv_arrange"
::method arrange unguarded external "LIBRARY oodialog lv_arrange"
::method bkColor unguarded external "LIBRARY oodialog lv_getColor"
::method "bkColor=" unguarded external "LIBRARY oodialog lv_setColor"
::method check unguarded external "LIBRARY oodialog lv_checkUncheck"
::method checkAll unguarded
   return self~check(-1)
::method columnInfo unguarded  -- Dialog units, not accurate.
   use strict arg index
   d = .Directory~new
   if self~getColumnInfo(index, d) then do
     colInfo.!TEXT = d~text
     colInfo.!WIDTH = d~width / self~factorX
     colInfo.!COLUMN = d~subItem
     colInfo.!ALIGN = d~alignment
     return colInfo.
   end

   colInfo.!WIDTH = 0
   return colInfo.

::method columnWidth unguarded  -- Dialog units, not accurate.
   use strict arg colNum
   return self~columnWidthPx(colNum) / self~factorX

::method columnWidthPx unguarded
   use strict arg column
   return self~sendWinIntMsg(self~LVM_GETCOLUMNWIDTH, column, 0)

::method delete unguarded external "LIBRARY oodialog lv_delete"
::method deleteAll unguarded external "LIBRARY oodialog lv_deleteAll"
::method deleteColumn unguarded external "LIBRARY oodialog lv_deleteColumn"
::method deselect unguarded external "LIBRARY oodialog lv_setSpecificState"
::method deselectAll unguarded external "LIBRARY oodialog lv_deselectAll"
::method dropHighlighted unguarded external "LIBRARY oodialog lv_getNextItemWithState"
::method edit unguarded
   use strict arg index
   if self~usingUnicode then return self~sendWinHandle2MsgH(self~LVM_EDITLABELW, index, 0)
   else return self~sendWinHandle2MsgH(self~LVM_EDITLABELA, index, 0)

::method endEdit unguarded
   use strict arg
   if self~usingUnicode then return self~sendWinHandle2MsgH(self~LVM_EDITLABELW, -1, 0)
   else return self~sendWinHandle2MsgH(self~LVM_EDITLABELA, -1, 0)

::method ensureVisible unguarded
   use strict arg index, partial = .false
   return self~sendWinIntMsg(self~LVM_ENSUREVISIBLE, index, partial) <> 0

::method find unguarded external "LIBRARY oodialog lv_find"
::method findNearestXY unguarded external "LIBRARY oodialog lv_findNearestXY"
::method findPartial unguarded external "LIBRARY oodialog lv_find"
::method firstVisible unguarded
   use strict arg
   return self~sendWinIntMsg(self~LVM_GETTOPINDEX , 0, 0)

::method fixFullRowColumns unguarded external "LIBRARY oodialog lv_fixFullRowColumns"
::method focus unguarded external "LIBRARY oodialog lv_setSpecificState"
::method focused unguarded external "LIBRARY oodialog lv_getNextItemWithState"
::method getCheck unguarded external "LIBRARY oodialog lv_getCheck"
::method getColumnCount unguarded external "LIBRARY oodialog lv_getColumnCount"
::method getColumnInfo unguarded  external "LIBRARY oodialog lv_getColumnInfo"
::method getColumnOrder unguarded external "LIBRARY oodialog lv_getColumnOrder"
::method getColumnText unguarded external "LIBRARY oodialog lv_getColumnText"
::method getExtendedStyle unguarded external "LIBRARY oodialog lv_getExtendedStyle"
::method getExtendedStyleRaw unguarded external "LIBRARY oodialog lv_getExtendedStyle"
::method getFullRow unguarded external "LIBRARY oodialog lv_getFullRow"
::method getHoverTime unguarded
   return self~sendWinIntMsg(self~LVM_GETHOVERTIME, 0, 0)

::method getImageList unguarded external "LIBRARY oodialog lv_getImageList"
::method getItem unguarded external "LIBRARY oodialog lv_getItem"
::method getItemData unguarded external "LIBRARY oodialog lv_getItemData"
::method getItemInfo unguarded external "LIBRARY oodialog lv_getItemInfo"
::method getItemRect unguarded external "LIBRARY oodialog lv_getItemRect"
::method getItemPos unguarded external "LIBRARY oodialog lv_getItemPos"
::method getSubitem unguarded external "LIBRARY oodialog lv_getSubitem"
::method getSubitemRect unguarded external "LIBRARY oodialog lv_getSubitemRect"
::method getToolTips unguarded external "LIBRARY oodialog generic_getToolTips"
::method getView unguarded external "LIBRARY oodialog lv_getView"
::method hasCheckBoxes unguarded external "LIBRARY oodialog lv_hasCheckBoxes"
::method hitTestInfo unguarded external "LIBRARY oodialog lv_hitTestInfo"
::method insert unguarded external "LIBRARY oodialog lv_insert"
::method insertColumn unguarded -- Dialog units, not accurate.
   use strict arg nr = 0, text, width, fmt = "L", adjustFullRows = .false
   width = trunc(width * self~factorX)
   return self~insertColumnPx(nr, text, width, fmt, adjustFullRows)

::method insertColumnPx unguarded external "LIBRARY oodialog lv_insertColumnPx"
::method insertFullRow unguarded external "LIBRARY oodialog lv_insertFullRow"
::method isChecked unguarded external "LIBRARY oodialog lv_isChecked"
::method itemInfo
   use strict arg index, subItem = 0
   d = .Directory~new
   if self~getItemInfo(index, d, subItem) then do
     itemInfo.!TEXT = d~text
     itemInfo.!IMAGE = d~image
     itemInfo.!STATE = d~state
     return itemInfo.
   end
   return -1

::method itemPos unguarded
   use strict arg item
   p = self~getItemPos(item)
   if p == 0 then return p
   else return p~x p~y

::method items unguarded
   return self~sendWinIntMsg(self~LVM_GETITEMCOUNT , 0, 0)

::method itemsPerPage unguarded
   return self~sendWinIntMsg(self~LVM_GETCOUNTPERPAGE, 0, 0)

::method itemState unguarded external "LIBRARY oodialog lv_itemState"
::method itemText unguarded external "LIBRARY oodialog lv_itemText"
::method last unguarded
   return self~items - 1

::method lastSelected unguarded
   if self~itemState(self~last)~wordpos("SELECTED") > 0 then  return self~last
   return self~previousSelected(self~last)

::method modify unguarded external "LIBRARY oodialog lv_modify"
::method modifyColumn unguarded  -- Dialog units, not accurate.
   use strict arg index, label = "", width = (-8), align = ""
   if arg(3,'E'), width~datatype('W') then width = width * self~factorX
   return self~modifyColumnPx(index, label, width, align)

::method modifyColumnPx unguarded external "LIBRARY oodialog lv_modifyColumnPx"
::method modifyFullRow unguarded external "LIBRARY oodialog lv_modifyFullRow"
::method modifyItem unguarded external "LIBRARY oodialog lv_modifyItem"
::method modifySubitem unguarded external "LIBRARY oodialog lv_modifySubitem"
::method next unguarded external "LIBRARY oodialog lv_getNextItem"
::method nextLeft unguarded external "LIBRARY oodialog lv_getNextItem"
::method nextRight unguarded external "LIBRARY oodialog lv_getNextItem"
::method nextSelected unguarded external "LIBRARY oodialog lv_getNextItem"
::method prepare4nItems unguarded
   use strict arg countItems
   return self~sendWinIntMsg(self~LVM_SETITEMCOUNT, countItems, 0)

::method prependFullRow unguarded external "LIBRARY oodialog lv_prependFullRow"
::method previous unguarded external "LIBRARY oodialog lv_getNextItem"
::method previousSelected unguarded external "LIBRARY oodialog lv_getNextItem"
::method redrawItems unguarded
   use strict arg first = 0, last = (self~items)
   return self~sendWinIntMsg(self~LVM_REDRAWITEMS, first, last) <> 0

::method removeExtendedStyle unguarded external "LIBRARY oodialog lv_addClearExtendStyle"
::method removeItemData unguarded external "LIBRARY oodialog lv_removeItemData"
::method removeStyle unguarded external "LIBRARY oodialog lv_addRemoveStyle"
::method replaceExtendedStyle unguarded external "LIBRARY oodialog lv_replaceExtendStyle"
::method replaceStyle unguarded external "LIBRARY oodialog lv_replaceStyle"
::method scroll unguarded
   use strict arg x = 0, y = 0
   return self~sendWinIntMsg(self~LVM_SCROLL, x, y) <> 0

::method select unguarded external "LIBRARY oodialog lv_setSpecificState"
::method selected unguarded external "LIBRARY oodialog lv_getNextItemWithState"
::method selectedItems unguarded
   return self~sendWinIntMsg(self~LVM_GETSELECTEDCOUNT , 0, 0)

::method setColumnOrder external "LIBRARY oodialog lv_setColumnOrder"
::method setColumnWidth unguarded  -- Dialog units, not accurate.
   use strict arg index, width = "AUTO"
   if width~datatype("W") then width = width * self~factorX
   return self~setColumnWidthPx(index, width)

::method setColumnWidthPx unguarded external "LIBRARY oodialog lv_setColumnWidthPx"
::method setFullRowText unguarded external "LIBRARY oodialog lv_setFullRowText"
::method setHoverTime unguarded
   use strict arg time = (-1)
   if time < -1 then time = -1
   return self~sendWinIntMsg(self~LVM_SETHOVERTIME, 0, time)

::method setImageList unguarded external "LIBRARY oodialog lv_setImageList"
::method setItemData unguarded external "LIBRARY oodialog lv_setItemData"
::method setItemPos unguarded external "LIBRARY oodialog lv_setItemPos"
::method setItemState unguarded external "LIBRARY oodialog lv_setItemState"
::method setItemText unguarded external "LIBRARY oodialog lv_setItemText"
::method setToolTips unguarded external "LIBRARY oodialog generic_setToolTips"
::method setView unguarded external "LIBRARY oodialog lv_setView"
::method smallSpacing unguarded
   return self~sendWinIntMsg(self~LVM_GETITEMSPACING, 1, 0)

::method snapToGrid unguarded external "LIBRARY oodialog lv_arrange"
::method sortItems unguarded external "LIBRARY oodialog lv_sortItems"
::method spacing unguarded
   return self~sendWinIntMsg(self~LVM_GETITEMSPACING, 0, 0)

::method stringWidth unguarded  -- Dialog units, not accurate.
   use strict arg text
   return self~stringWidthPx(text) / self~factorX

::method stringWidthPx unguarded external "LIBRARY oodialog lv_stringWidthPx"
::method textBkColor unguarded external "LIBRARY oodialog lv_getColor"
::method "textBkColor=" unguarded external "LIBRARY oodialog lv_setColor"
::method textColor unguarded external "LIBRARY oodialog lv_getColor"
::method "textColor=" unguarded external "LIBRARY oodialog lv_setColor"
::method uncheck unguarded external "LIBRARY oodialog lv_checkUncheck"
::method uncheckAll unguarded
   return self~uncheck(-1)

::method updateItem unguarded
   use strict arg index
   return self~sendWinIntMsg(self~LVM_UPDATE, index, 0) == 0


::method zTest unguarded external "LIBRARY oodialog lv_zTest"             -- internal use only

-- DEPRECATED to end of Class
::method removeImages unguarded                                           -- DEPRECATED
   return self~removeImageList(.nil, 0)


::method removeSmallImages unguarded                                      -- DEPRECATED
   return self~removeImageList(.nil, 1)

::method restoreEditClass                                                 -- DEPRECATED

::method setImages unguarded external "LIBRARY oodialog lv_setImageList"  -- DEPRECATED

::method setSmallImages unguarded                                         -- DEPRECATED
   newArgs = arg(1, 'A')
   newArgs[4] = 1
   forward message 'setImageList' arguments (newArgs)

::method subclassEdit                                                     -- DEPRECATED


::class 'LvCustomDrawSimple' public
::method init class external       "LIBRARY oodialog lvcds_init_cls"
::method init external             "LIBRARY oodialog lvcds_init"

::attribute clrText set external   "LIBRARY oodialog lvcds_setClrText"
::attribute clrTextBk set external "LIBRARY oodialog lvcds_setClrTextBk"
::attribute drawStage get external "LIBRARY oodialog lvcds_getDrawStage"
::attribute font set external      "LIBRARY oodialog lvcds_setFont"
::attribute id get external        "LIBRARY oodialog lvcds_getID"
::attribute item get external      "LIBRARY oodialog lvcds_getItem"
::attribute itemData get external  "LIBRARY oodialog lvcds_getItemData"
::attribute reply set external     "LIBRARY oodialog lvcds_setReply"
::attribute subItem get external   "LIBRARY oodialog lvcds_getSubItem"



::class 'LvItem' public

::method init class external "LIBRARY oodialog lvi_init_cls"

::method init external "LIBRARY oodialog lvi_init"
::method unInit external "LIBRARY oodialog lvi_unInit"

::attribute columnFormats get external "LIBRARY oodialog lvi_columnFormats"
::attribute columnFormats set external "LIBRARY oodialog lvi_setColumnFormats"
::attribute columns get external "LIBRARY oodialog lvi_columns"
::attribute columns set external "LIBRARY oodialog lvi_setColumns"
::attribute groupID get external "LIBRARY oodialog lvi_groupID"
::attribute groupID set external "LIBRARY oodialog lvi_setGroupID"
::attribute imageIndex get external "LIBRARY oodialog lvi_imageIndex"
::attribute imageIndex set external "LIBRARY oodialog lvi_setImageIndex"
::attribute indent get external "LIBRARY oodialog lvi_indent"
::attribute indent set external "LIBRARY oodialog lvi_setIndent"
::attribute index get external "LIBRARY oodialog lvi_index"
::attribute index set external "LIBRARY oodialog lvi_setIndex"
::attribute itemData get external "LIBRARY oodialog lvi_itemData"
::attribute itemData set external "LIBRARY oodialog lvi_setItemData"
::attribute itemState get external "LIBRARY oodialog lvi_itemState"
::attribute itemState set external "LIBRARY oodialog lvi_setItemState"
::attribute itemStateMask get external "LIBRARY oodialog lvi_itemStateMask"
::attribute itemStateMask set external "LIBRARY oodialog lvi_setItemStateMask"
::attribute mask get external "LIBRARY oodialog lvi_mask"
::attribute mask set external "LIBRARY oodialog lvi_setMask"
::attribute overlayImageIndex get external "LIBRARY oodialog lvi_overLayImageIndex"
::attribute overlayImageIndex set external "LIBRARY oodialog lvi_setOverlayImageIndex"
::attribute stateImageIndex get external "LIBRARY oodialog lvi_stateImageIndex"
::attribute stateImageIndex set external "LIBRARY oodialog lvi_setStateImageIndex"
::attribute text get external "LIBRARY oodialog lvi_text"
::attribute text set external "LIBRARY oodialog lvi_setText"


::class 'LvFullRow' public
::method init class external "LIBRARY oodialog lvfr_init_cls"
::method fromArray class external "LIBRARY oodialog lvfr_fromArray_cls"

::method init external "LIBRARY oodialog lvfr_init"
::method unInit external "LIBRARY oodialog lvfr_unInit"

::attribute userData get external "LIBRARY oodialog lvfr_userData"
::attribute userData set external "LIBRARY oodialog lvfr_setUserData"

::method addSubItem external "LIBRARY oodialog lvfr_addSubitem"
::method insertSubitem external "LIBRARY oodialog lvfr_insertSubitem"
::method item external "LIBRARY oodialog lvfr_item"
::method removeSubItem external "LIBRARY oodialog lvfr_removeSubitem"
::method subItem external "LIBRARY oodialog lvfr_subitem"
::method subItems external "LIBRARY oodialog lvfr_subitems"


::class 'LvSubItem' public
::method init class external "LIBRARY oodialog lvsi_init_cls"

::method init external "LIBRARY oodialog lvsi_init"
::method unInit external "LIBRARY oodialog lvsi_unInit"

::attribute imageIndex get external "LIBRARY oodialog lvsi_imageIndex"
::attribute imageIndex set external "LIBRARY oodialog lvsi_setImageIndex"
::attribute item get external "LIBRARY oodialog lvsi_item"
::attribute item set external "LIBRARY oodialog lvsi_setItem"
::attribute mask get external "LIBRARY oodialog lvsi_mask"
::attribute mask set external "LIBRARY oodialog lvsi_setMask"
::attribute subItem get external "LIBRARY oodialog lvsi_subItem"
::attribute subItem set external "LIBRARY oodialog lvsi_setSubItem"
::attribute text get external "LIBRARY oodialog lvsi_text"
::attribute text set external "LIBRARY oodialog lvsi_setText"



/**
 * Windows Dialog Interface for Open Object Rexx (ooRexx.)
 *
 * ReBar and ReBar helper classes.
 */

::class 'ReBar' subclass DialogControl public

::method deleteBand unguarded external "LIBRARY oodialog rebar_deleteBand"
::method getBandBorders unguarded external "LIBRARY oodialog rebar_getBandBorders"
::method getBandCount unguarded external "LIBRARY oodialog rebar_getBandCount"
::method getBandInfo unguarded external "LIBRARY oodialog rebar_getBandInfo"
::method getBandMargins unguarded external "LIBRARY oodialog rebar_getBandMargins"
::method getBarHeight unguarded external "LIBRARY oodialog rebar_getBarHeight"
::method getBarInfo unguarded external "LIBRARY oodialog rebar_getBarInfo"
::method getBkColor unguarded external "LIBRARY oodialog rebar_getBkColor"
::method getColorScheme unguarded external "LIBRARY oodialog rebar_getColorScheme"
::method getExtendedStyle unguarded external "LIBRARY oodialog rebar_getExtendedStyle"
::method getImageList unguarded external "LIBRARY oodialog rebar_getBarInfo"
::method getPalette unguarded external "LIBRARY oodialog rebar_getPalette"
::method getRect unguarded external "LIBRARY oodialog rebar_getRect"
::method getRowCount unguarded external "LIBRARY oodialog rebar_getRowCount"
::method getRowHeight unguarded external "LIBRARY oodialog rebar_getRowHeight"
::method getTextColor unguarded external "LIBRARY oodialog rebar_getTextColor"
::method getToolTips unguarded external "LIBRARY oodialog generic_getToolTips"
::method hitTestInfo unguarded external "LIBRARY oodialog rebar_hitTestInfo"
::method idToIndex unguarded external "LIBRARY oodialog rebar_idToIndex"
::method insertBand unguarded external "LIBRARY oodialog rebar_insertBand"
::method maximizeBand unguarded external "LIBRARY oodialog rebar_maximizeBand"
::method minimizeBand unguarded external "LIBRARY oodialog rebar_minimizeBand"
::method moveBand unguarded external "LIBRARY oodialog rebar_moveBand"
::method pushChevron unguarded external "LIBRARY oodialog rebar_pushChevron"
::method setBandInfo unguarded external "LIBRARY oodialog rebar_setBandInfo"
::method setBandWidth unguarded external "LIBRARY oodialog rebar_setBandWidth"
::method setBarInfo unguarded external "LIBRARY oodialog rebar_setBarInfo"
::method setBkColor unguarded external "LIBRARY oodialog rebar_setBkColor"
::method setColorScheme unguarded external "LIBRARY oodialog rebar_setColorScheme"
::method setExtendedStyle unguarded external "LIBRARY oodialog rebar_setExtendedStyle"
::method setImageList unguarded external "LIBRARY oodialog rebar_setBarInfo"
::method setPalette unguarded external "LIBRARY oodialog rebar_setPalette"
::method setParent unguarded external "LIBRARY oodialog rebar_setParent"
::method setTextColor unguarded external "LIBRARY oodialog rebar_setTextColor"
::method setToolTips unguarded external "LIBRARY oodialog generic_setToolTips"
::method setWindowTheme unguarded external "LIBRARY oodialog rebar_setWindowTheme"
::method showBand unguarded external "LIBRARY oodialog rebar_showBand"
::method sizeToRect unguarded external "LIBRARY oodialog rebar_sizeToRect"


::class 'ReBarBandInfo' public

::method init class external "LIBRARY oodialog rbbi_init_cls"

::method init external "LIBRARY oodialog rbbi_init"
::method unInit external "LIBRARY oodialog rbbi_unInit"

::attribute bitmapBack get external "LIBRARY oodialog rbbi_bitmapBack"
::attribute bitmapBack set external "LIBRARY oodialog rbbi_setBitmapBack"
::attribute chevronLocation get external "LIBRARY oodialog rbbi_chevronLocation"
::attribute chevronLocation set external "LIBRARY oodialog rbbi_setChevronLocation"
::attribute chevronState get external "LIBRARY oodialog rbbi_chevronState"
::attribute chevronState set external "LIBRARY oodialog rbbi_setChevronState"
::attribute child get external "LIBRARY oodialog rbbi_child"
::attribute child set external "LIBRARY oodialog rbbi_setChild"
::attribute clrBack get external "LIBRARY oodialog rbbi_clrBack"
::attribute clrBack set external "LIBRARY oodialog rbbi_setClrBack"
::attribute clrFore get external "LIBRARY oodialog rbbi_clrFore"
::attribute clrFore set external "LIBRARY oodialog rbbi_setClrFore"
::attribute cx get external "LIBRARY oodialog rbbi_cx"
::attribute cx set external "LIBRARY oodialog rbbi_setCx"
::attribute cxHeader get external "LIBRARY oodialog rbbi_cxHeader"
::attribute cxHeader set external "LIBRARY oodialog rbbi_setCxHeader"
::attribute cxIdeal get external "LIBRARY oodialog rbbi_cxIdeal"
::attribute cxIdeal set external "LIBRARY oodialog rbbi_setCxIdeal"
::attribute cxMinChild get external "LIBRARY oodialog rbbi_cxMinChild"
::attribute cxMinChild set external "LIBRARY oodialog rbbi_setCxMinChild"
::attribute cyChild get external "LIBRARY oodialog rbbi_cyChild"
::attribute cyChild set external "LIBRARY oodialog rbbi_setCyChild"
::attribute cyIntegral get external "LIBRARY oodialog rbbi_cyIntegral"
::attribute cyIntegral set external "LIBRARY oodialog rbbi_setcyIntegral"
::attribute cyMaxChild get external "LIBRARY oodialog rbbi_cyMaxChild"
::attribute cyMaxChild set external "LIBRARY oodialog rbbi_setCyMaxChild"
::attribute cyMinChild get external "LIBRARY oodialog rbbi_cyMinChild"
::attribute cyMinChild set external "LIBRARY oodialog rbbi_setCyMinChild"
::attribute id get external "LIBRARY oodialog rbbi_id"
::attribute id set external "LIBRARY oodialog rbbi_setId"
::attribute imageIndex get external "LIBRARY oodialog rbbi_imageIndex"
::attribute imageIndex set external "LIBRARY oodialog rbbi_setImageIndex"
::attribute itemData get external "LIBRARY oodialog rbbi_itemData"
::attribute itemData set external "LIBRARY oodialog rbbi_setItemData"
::attribute mask get external "LIBRARY oodialog rbbi_mask"
::attribute mask set external "LIBRARY oodialog rbbi_setMask"
::attribute style get external "LIBRARY oodialog rbbi_style"
::attribute style set external "LIBRARY oodialog rbbi_setStyle"
::attribute text get external "LIBRARY oodialog rbbi_text"
::attribute text set external "LIBRARY oodialog rbbi_setText"

/**
 * Windows Dialog Interface for Open Object Rexx (ooRexx.)
 *
 * StatusBar class.
 */

::class 'StatusBar' subclass DialogControl public

::method getBorders external  "LIBRARY oodialog stb_getBorders"
::method getIcon external  "LIBRARY oodialog stb_getIcon"
::method getParts external  "LIBRARY oodialog stb_getParts"
::method getRect external  "LIBRARY oodialog stb_getRect"
::method getText external  "LIBRARY oodialog stb_getText"
::method getTextLength external  "LIBRARY oodialog stb_getTextLength"
::method getTipText external  "LIBRARY oodialog stb_getTipText"
::method isSimple external  "LIBRARY oodialog stb_isSimple"
::method setBkColor external  "LIBRARY oodialog stb_setBkColor"
::method setIcon external  "LIBRARY oodialog stb_setIcon"
::method setMinHeight external  "LIBRARY oodialog stb_setMinHeight"
::method setParts external  "LIBRARY oodialog stb_setParts"
::method setText external  "LIBRARY oodialog stb_setText"
::method setTipText external  "LIBRARY oodialog stb_setTipText"
::method simple	external  "LIBRARY oodialog stb_simple"



/**
 * Windows Dialog Interface for Open Object Rexx (ooRexx.)
 *
 * TreeView Class.
 */

::class 'TreeControl' subclass DialogControl public
::class 'TreeView' subclass TreeControl public

-- TV_FIRST == 0x1100  (4352)
::constant TVM_DELETEITEM          "0x1101"
::constant TVM_EDITLABELA          "0x110E"
::constant TVM_EDITLABELW          "0x1141"
::constant TVM_ENDEDITLABELNOW     "0x1116"
::constant TVM_ENSUREVISIBLE       "0x1114"
::constant TVM_GETCOUNT            "0x1105"
::constant TVM_GETINDENT           "0x1106"
::constant TVM_GETUNICODEFORMAT    "0x2006"
::constant TVM_GETVISIBLECOUNT     "0x1110"
::constant TVM_SETINDENT           "0x1107"
::constant TVM_SORTCHILDREN        "0x1113"

::attribute rootArray private

::method init
   forward class (super) continue
   self~rootArray = .array~new(4)


::method add unguarded
   do i = 1 to arg()
      if arg(i, 'E') then do
          if arg(i + 1, 'E') then image    = arg(i + 1); else image = -1
          if arg(i + 2, 'E') then selImage = arg(i + 2); else selImage = image
          if arg(i + 3, 'E') then opts     = arg(i + 3); else opts = ""
          if arg(i + 4, 'E') then children = arg(i + 4); else children = 0
          if arg(i + 5, 'E') then itemData = arg(i + 5); else itemData = .nil
          if i = 1 then do
              self~rootArray[i] = self~insert("ROOT", , arg(i), image, selimage, opts~translate, children, itemData)
              return self~rootArray[i]
          end
          else if self~rootArray~hasIndex(i - 1) then do
              if i = 1 then parent = "ROOT"; else parent = self~rootArray[i - 1]
              self~rootArray[i] = self~insert(parent, , arg(i), image, selimage, opts~translate, children, itemData)
              return self~rootArray[i]
          end
          else return 0
      end
   end

::method child unguarded external "LIBRARY oodialog tv_getNextItem"
::method collapse unguarded external "LIBRARY oodialog tv_expand"
::method collapseAndReset unguarded external "LIBRARY oodialog tv_expand"
::method delete unguarded external "LIBRARY oodialog tv_delete"
::method deleteAll unguarded external "LIBRARY oodialog tv_deleteAll"
::method dropHighlight unguarded external "LIBRARY oodialog tv_selectItem"
::method dropHighlighted unguarded external "LIBRARY oodialog tv_getSpecificItem"
::method edit unguarded
   use strict arg hitem
   if self~usingUnicode then return self~sendWinHandle2MsgH(self~TVM_EDITLABELW, 0, hItem)
   else return self~sendWinHandle2MsgH(self~TVM_EDITLABELA, 0, hItem)

::method endEdit unguarded
   use strict arg cancel = .false
   return (self~sendWinIntMsg(self~TVM_ENDEDITLABELNOW , cancel, 0) <> 0)

::method ensureVisible unguarded
   use strict arg hItem
   return self~sendWinHandle2Msg(self~TVM_ENSUREVISIBLE, 0, hItem)

::method expand unguarded external "LIBRARY oodialog tv_expand"
::method find unguarded external "LIBRARY oodialog tv_find"
::method firstVisible unguarded external "LIBRARY oodialog tv_getSpecificItem"
::method getImageList unguarded external "LIBRARY oodialog tv_getImageList"
::method getItemData unguarded external "LIBRARY oodialog tv_getItemData"
::method getItemHeight unguarded external "LIBRARY oodialog tv_getItemHeight"
::method getItemRect unguarded external "LIBRARY oodialog tv_getItemRect"
::method getStateImage unguarded external "LIBRARY oodialog tv_getStateImage"
::method getToolTips unguarded external "LIBRARY oodialog generic_getToolTips"
::method hitTestInfo unguarded external "LIBRARY oodialog tv_hitTestInfo"
::method indent unguarded
   use strict arg
   return self~sendWinIntMsg(self~TVM_GETINDENT, 0, 0)

::method "indent=" unguarded
   use strict arg indentAmount
   return self~sendWinIntMsg(self~TVM_SETINDENT, indentAmount, 0)

::method insert unguarded external "LIBRARY oodialog tv_insert"
::method isAncestor unguarded
   use strict arg hParent, hItem
   if arg(1, 'O') | hParent = 0 then return .false
   if arg(2, 'O') | hItem = 0 then return .false
   if hItem = hParent then return .false
   ancestor = self~parent(hItem)
   do while ancestor \= 0 & ancestor \= hParent
       ancestor = self~Parent(ancestor)
   end
   if ancestor = hParent then return .true
   else return .false

::method itemInfo unguarded external "LIBRARY oodialog tv_itemInfo"
::method items unguarded
   use strict arg
   return self~sendWinIntMsg(self~TVM_GETCOUNT, 0, 0)

::method itemText unguarded external "LIBRARY oodialog tv_itemText"
::method makeFirstVisible unguarded external "LIBRARY oodialog tv_selectItem"
::method modify unguarded external "LIBRARY oodialog tv_modify"
::method moveItem unguarded
   use strict arg hItem, hNewParent, redraw = .true, extended = ""
   if hItem = 0 then return 0
   if hNewParent = 0 then return 0

   extended = extended~translate
   if hItem = hNewParent | hNewParent = self~parent(hItem) | self~isAncestor(hItem, hNewParent) then return 0
   iinfo. = self~itemInfo(hItem)
   newRoot = self~insert(hNewParent, , iinfo.!Text, iinfo.!Image, iinfo.!SelectedImage, iinfo.!State, iinfo.!Children, -
                         iinfo.!itemData)

   if iinfo.!Children = 1 then do
      child = self~child(hItem)
      if child \= 0 then self~moveItem(child, newRoot, 0, "SIBLINGS")
   end

   if extended = "SIBLINGS" then do
      sibling = self~next(hItem)
      do while sibling \= 0
         self~moveItem(sibling, hNewParent, 0, "NODELETE")
         oldSib = sibling
         sibling = self~next(sibling)
         self~delete(oldSib)
      end
   end

   if extended \= "NODELETE" then self~delete(hItem)
   if redraw then self~update
   return newRoot

::method next unguarded external "LIBRARY oodialog tv_getNextItem"
::method nextVisible unguarded external "LIBRARY oodialog tv_getNextItem"
::method parent unguarded external "LIBRARY oodialog tv_getNextItem"
::method previous unguarded external "LIBRARY oodialog tv_getNextItem"
::method previousVisible unguarded external "LIBRARY oodialog tv_getNextItem"
::method removeItemData external "LIBRARY oodialog tv_removeItemData"
::method root unguarded external "LIBRARY oodialog tv_getSpecificItem"
::method select unguarded external "LIBRARY oodialog tv_selectItem"
::method selected unguarded external "LIBRARY oodialog tv_getSpecificItem"
::method setImageList unguarded external "LIBRARY oodialog tv_setImageList"
::method setItemData unguarded external "LIBRARY oodialog tv_setItemData"
::method setItemHeight unguarded external "LIBRARY oodialog tv_setItemHeight"
::method setStateImage unguarded external "LIBRARY oodialog tv_setStateImage"
::method setToolTips unguarded external "LIBRARY oodialog generic_setToolTips"

-- The old code did not have recurse arg and had a comment saying "recursive not yet supported"
-- Although MSDN documents this message as recursively sorting the children if WPARAM is true,
-- it doesn't seem to work.
::method sortChildren unguarded
   use strict arg hitem, recurse = .false
   return self~sendWinHandle2Msg(self~TVM_SORTCHILDREN, recurse, hItem)

::method sortChildrenCB external "LIBRARY oodialog tv_sortChildrenCB"
::method toggle unguarded external "LIBRARY oodialog tv_expand"

::method visibleItems unguarded
   use strict arg
   return self~sendWinIntMsg(self~TVM_GETVISIBLECOUNT, 0, 0)

::method test unguarded external "LIBRARY oodialog tv_test"


-- DEPRECATED
::method hitTest unguarded
   forward message "hitTestInfo" continue
   info = result
   if info~hItem = 0 then return 0
   else return info~hItem info~location  -- This looks goofy, but it is what the original code did

::method removeImages unguarded
   return self~setImageList(.nil, 0)

-- DEPRECATED
::method restoreEditClass

-- DEPRECATED
::method setImages unguarded external "LIBRARY oodialog tv_setImageList"

-- DEPRECATED
::method subclassEdit


::class 'TvCustomDrawSimple' public
::method init class external       "LIBRARY oodialog tvcds_init_cls"
::method init external             "LIBRARY oodialog tvcds_init"
::attribute clrText set external   "LIBRARY oodialog tvcds_setClrText"
::attribute clrTextBk set external "LIBRARY oodialog tvcds_setClrTextBk"
::attribute drawStage get external "LIBRARY oodialog tvcds_getDrawStage"
::attribute font set external      "LIBRARY oodialog tvcds_setFont"
::attribute id get external        "LIBRARY oodialog tvcds_getID"
::attribute item get external      "LIBRARY oodialog tvcds_getItem"
::attribute itemData get external  "LIBRARY oodialog tvcds_getItemData"
::attribute reply set external     "LIBRARY oodialog tvcds_setReply"
::attribute level get external     "LIBRARY oodialog tvcds_getLevel"

/**
 * Windows Dialog Interface for Open Object Rexx (ooRexx.)
 *
 * ToolBar and ToolBar helper classes.
 */

::class 'ToolBar' subclass DialogControl public

::method addBitmap external  "LIBRARY oodialog tb_addBitmap"
::method addButtons external  "LIBRARY oodialog tb_addButtons"
::method addString external  "LIBRARY oodialog tb_addString"
::method autoSize external  "LIBRARY oodialog tb_autoSize"
::method buttonCount external  "LIBRARY oodialog tb_buttonCount"
::method changeBitmap external  "LIBRARY oodialog tb_changeBitmap"
::method checkButton external  "LIBRARY oodialog tb_checkButton"
::method commandToIndex external  "LIBRARY oodialog tb_commandToIndex"
::method customize external  "LIBRARY oodialog tb_customize"
::method enableButton external  "LIBRARY oodialog tb_enableButton"
::method getButton external  "LIBRARY oodialog tb_getButton"
::method getButtonText external  "LIBRARY oodialog tb_getButtonText"
::method getButtonTextEx external  "LIBRARY oodialog tb_getButtonTextEx"
::method getDisabledImageList external  "LIBRARY oodialog tb_getDisabledImageList"
::method getExtendedStyle external  "LIBRARY oodialog tb_getExtendedStyle"
::method getHotImageList external  "LIBRARY oodialog tb_getHotImageList"
::method getImageList external  "LIBRARY oodialog tb_getImageList"
::method getPressedImageList external  "LIBRARY oodialog tb_getPressedImageList"
::method indexTocommand external  "LIBRARY oodialog tb_indexTocommand"
::method insertButton external  "LIBRARY oodialog tb_insertButton"
::method isButtonChecked external  "LIBRARY oodialog tb_isButtonChecked"
::method isButtonEnabled external  "LIBRARY oodialog tb_isButtonEnabled"
::method isButtonHidden external  "LIBRARY oodialog tb_isButtonHidden"
::method isButtonHighlighted external  "LIBRARY oodialog tb_isButtonHighlighted"
::method isButtonIndeterminate external  "LIBRARY oodialog tb_isButtonIndeterminate"
::method isButtonPressed external  "LIBRARY oodialog tb_isButtonPressed"
::method loadImages external  "LIBRARY oodialog tb_loadImages"
::method setBitmapSize external  "LIBRARY oodialog tb_setBitmapSize"
::method setButtonText external  "LIBRARY oodialog tb_setButtonText"
::method setDisabledImageList external  "LIBRARY oodialog tb_setDisabledImageList"
::method setExtendedStyle external  "LIBRARY oodialog tb_setExtendedStyle"
::method setHotImageList external  "LIBRARY oodialog tb_setHotImageList"
::method setImageList external  "LIBRARY oodialog tb_setImageList"
::method setPressedImageList external  "LIBRARY oodialog tb_setPressedImageList"


::class 'TbButton' public

::method init class external "LIBRARY oodialog tbb_init_cls"

::method init external "LIBRARY oodialog tbb_init"

::attribute bitmapID get external "LIBRARY oodialog tbb_bitmapID"
::attribute bitmapID set external "LIBRARY oodialog tbb_setBitmapID"
::attribute cmdID get external "LIBRARY oodialog tbb_cmdID"
::attribute cmdID set external "LIBRARY oodialog tbb_setCmdID"
::attribute itemData get external "LIBRARY oodialog tbb_itemData"
::attribute itemData set external "LIBRARY oodialog tbb_setItemData"
::attribute state get external "LIBRARY oodialog tbb_state"
::attribute state set external "LIBRARY oodialog tbb_setState"
::attribute style get external "LIBRARY oodialog tbb_style"
::attribute style set external "LIBRARY oodialog tbb_setStyle"
::attribute text get external "LIBRARY oodialog tbb_text"
::attribute text set external "LIBRARY oodialog tbb_setText"

::method assignBitmapID external "LIBRARY oodialog tbb_assignBitmapID"

/**
 * Windows Dialog Interface for Open Object Rexx (ooRexx.)
 *
 * ToolTip Class.
 */

::class 'ToolTip' subclass DialogControl public

::method activate unguarded external "LIBRARY oodialog tt_activate"
::method addTool unguarded external "LIBRARY oodialog tt_addTool"
::method addToolEx unguarded external "LIBRARY oodialog tt_addToolEx"
::method addToolRect unguarded external "LIBRARY oodialog tt_addToolRect"
::method adjustRect unguarded external "LIBRARY oodialog tt_adjustRect"
::method delTool unguarded external "LIBRARY oodialog tt_delTool"
::method enumTools unguarded external "LIBRARY oodialog tt_enumTools"
::method getBubbleSize unguarded external "LIBRARY oodialog tt_getBubbleSize"
::method getCurrentToolInfo unguarded external "LIBRARY oodialog tt_getCurrentTool"
::method getDelayTime unguarded external "LIBRARY oodialog tt_getDelayTime"
::method getMargin unguarded external "LIBRARY oodialog tt_getMargin"
::method getMaxTipWidth unguarded external "LIBRARY oodialog tt_getMaxTipWidth"
::method getText unguarded external "LIBRARY oodialog tt_getText"
::method getTipBkColor unguarded external "LIBRARY oodialog tt_getTipBkColor"
::method getTipTextColor unguarded external "LIBRARY oodialog tt_getTipTextColor"
::method getTitle unguarded external "LIBRARY oodialog tt_getTitle"
::method getToolCount unguarded external "LIBRARY oodialog tt_getToolCount"
::method getToolInfo unguarded external "LIBRARY oodialog tt_getToolInfo"
::method hasCurrentTool unguarded external "LIBRARY oodialog tt_hasCurrentTool"
::method hitTest unguarded external "LIBRARY oodialog tt_hitTestInfo"  -- Erroneously named in ooDialog 4.2.1 doc, need to preserve for backwards compatibility, but no longer documented.
::method hitTestInfo unguarded external "LIBRARY oodialog tt_hitTestInfo"
::method manageAtypicalTool unguarded external "LIBRARY oodialog tt_manageAtypicalTool"
::method newToolRect unguarded external "LIBRARY oodialog tt_newToolRect"
::method pop unguarded external "LIBRARY oodialog tt_pop"
::method popUp unguarded external "LIBRARY oodialog tt_popUp"
::method setDelayTime unguarded external "LIBRARY oodialog tt_setDelayTime"
::method setMargin unguarded external "LIBRARY oodialog tt_setMargin"
::method setMaxTipWidth unguarded external "LIBRARY oodialog tt_setMaxTipWidth"
::method setTipBkColor unguarded external "LIBRARY oodialog tt_setTipBkColor"
::method setTipTextColor unguarded external "LIBRARY oodialog tt_setTipTextColor"
::method setTitle unguarded external "LIBRARY oodialog tt_setTitle"
::method setToolInfo unguarded external "LIBRARY oodialog tt_setToolInfo"
::method setWindowTheme unguarded external "LIBRARY oodialog tt_setWindowTheme"
::method trackActivate unguarded external "LIBRARY oodialog tt_trackActivate"
::method trackPosition unguarded external "LIBRARY oodialog tt_trackPosition"
::method update unguarded external "LIBRARY oodialog tt_update"
::method updateTipText unguarded external "LIBRARY oodialog tt_updateTipText"


::class 'ToolInfo' public
::method forHitTest class external "LIBRARY oodialog ti_forHitTest_cls"
::method forID class external "LIBRARY oodialog ti_forID_cls"

::method init external "LIBRARY oodialog ti_init"
::method unInit external "LIBRARY oodialog ti_unInit"

::attribute flags get external "LIBRARY oodialog ti_flags"
::attribute flags set external "LIBRARY oodialog ti_setFlags"
::attribute rect get external "LIBRARY oodialog ti_rect"
::attribute rect set external "LIBRARY oodialog ti_setRect"
::attribute resource get external "LIBRARY oodialog ti_resource"
::attribute rexxHwnd get external "LIBRARY oodialog ti_rexxHwnd"
::attribute rexxID get external "LIBRARY oodialog ti_rexxID"
::attribute text get external "LIBRARY oodialog ti_text"
::attribute text set external "LIBRARY oodialog ti_setText"
::attribute userData get external "LIBRARY oodialog ti_userData"
::attribute userData set external "LIBRARY oodialog ti_setUserData"

::attribute textMemoryIsAllocated set external "LIBRARY oodialog ti_setTextMemoryIsAllocated"  -- Internal use only.
::method hitTestHelper external "LIBRARY oodialog ti_hitTestHelper"                            -- Internal use only.


/**
 * Windows Dialog Interface for Open Object Rexx (ooRexx.)
 *
 * Dialog class extensions.
 */

::class 'DialogExtensions' public mixinclass Object

-- Like execute(), but does not wait for the dialog to close. Do not document
-- modeless, it is an implementation detail that may be removed if true modal
-- dialog are ever implemented. sleepTime on the other hand *was* documented.
::method executeAsync unguarded
   use strict arg sleepTime = 1, sh = "NORMAL", icon = 0, modeless = .false

   if self~startIt(icon, modeless) \= 0 then do
      if self~useStem then self~setDataStem(self~dlgData)
      else self~setData
      self~show(sh)

      do while self~automaticMethods~Items > 0
         p = self~automaticMethods~pull
         m = self~automaticMethods~pull
         c = self~automaticMethods~pull
         o = c~new(p, self)
         o~start(m)
      end
      return 0
   end
   else do
      self~finished = .true
      self~stopit
      return 1
   end

-- Used to wait for a dialog started through executeAsync() to end.
::method endAsyncExecution unguarded

   self~waitForDialog

   if self~initCode = 1 then do
      if self~useStem then self~getDataStem(self~dlgData)
      self~getData
   end
   self~stopit
   return self~initCode

-- Run a modeless dialog
::method popup
   use strict arg sh = "NORMAL", sleepTime = 1, icon = 0
   return self~start("execute", sh, icon, sleeptime, .true)

-- Run a modeless dialog that will be automatically closed when its parent closes.
::method popupAsChild
   use strict arg parent, sh = "NORMAL", sleepTime = 1, icon = 0

   if \ parent~isA(.PlainBaseDialog) then do
       call errorDialog "Specified parent is not a dialog!"
       return -1
   end

   parent~childDialogs~insert(self)  /* add to the parents child list (last item) */
   self~parentDlg = parent

   return self~start("execute", sh, icon, sleeptime, .true)

::method setSBRange unguarded
   use strict arg id, min, max, redraw = .true
   sb = self~newScrollBar(id)
   if sb == .nil then return -1
   return sb~setRange(min, max, redraw)

::method getSBRange unguarded   -- Old method, returns a string.  Not going to add an enhanced method.
   use strict arg id
   sb = self~newScrollBar(id)
   if sb == .nil then return -1
   return sb~range

::method setSBPos unguarded
   use strict arg id, pos, redraw = .true
   sb = self~newScrollBar(id)
   if sb == .nil then return -1
   return sb~setPos(pos, redraw)

::method getSBPos unguarded
   use strict arg id
   sb = self~newScrollBar(id)
   if sb == .nil then return -1
   return sb~getPos

::method determineSBPosition unguarded
   use strict arg id, posdata, single = 1, page = 10
   sb = self~newScrollBar(id)
   if sb == .nil then return -1
   return sb~determinePosition

::method getListWidthPx unguarded
   use strict arg id
   listBox = self~newListBox(id)
   if listBox == .nil then return -1
   return listBox~widthPx

::method setListColumnWidthPx unguarded
   use strict arg id, pixels
   listBox = self~newListBox(id)
   if listBox == .nil then return -1
   listBox~columnWidthPx = pixels
   return 0

::method setListItemHeightPx unguarded
   use strict arg id, pixels
   listBox = self~newListBox(id)
   if listBox == .nil then return -1
   listBox~listItemHeightPx = pixels
   return 0

::method setListWidthPx unguarded
   use strict arg id, pixels
   listBox = self~newListBox(id)
   if listBox == .nil then return -1
   listBox~setWidthPx(pixels)
   return 0

::method getListItemHeightPx unguarded
   use strict arg id
   listBox = self~newListBox(id)
   if listBox == .nil then return -1
   return listBox~itemHeightPx

::method setListWidth unguarded         -- Old method uses dialog units - not accurate
   use strict arg id, dlgunits
   pixels = dlgunits * self~factorX
   return self~setListWidthPx(id, pixels)

::method getListWidth unguarded         -- Old method uses dialog units - not accurate
   use strict arg id
   pixels = self~getListWidthPx(id)
   if pixels <= 0 then return pixels
   else return pixels / self~factorX

::method setListColumnWidth unguarded   -- Old method uses dialog units - not accurate
   use strict arg id, dlgunits
   pixels = dlgunits * self~factorX
   return self~setListColumnWidthPx(id, pixels)

::method setListItemHeight unguarded    -- Old method uses dialog units - not accurate
   use strict arg id, dlgunits
   pixels = dlgunits * self~factorY
   return self~setListItemHeightPx(id, pixels)

::method getListItemHeight unguarded    -- Old method uses dialog units - not accurate
   use strict arg id
   pixels = self~getListItemHeightPx(id)
   if pixes <= 0 then return pixels
   else return pixels / self~factorY

::method setControlFont unguarded
   use strict arg id, hFont, bRedraw = .true
   hCtrl = self~getControlHandle(id)
   return self~sendWinHandleMsg(self~WM_SETFONT, hFont, bRedraw, hCtrl)

::method setControlSysColor external "LIBRARY oodialog dlgext_setControlColor"
::method setControlColor external "LIBRARY oodialog dlgext_setControlColor"

::method setWindowRect unguarded external "LIBRARY oodialog dlgext_setWindowRect"
::method getControlRect unguarded external "LIBRARY oodialog dlgext_getControlRect"
::method resizeControl unguarded external "LIBRARY oodialog dlgext_resizeMoveControl"
::method moveControl unguarded external "LIBRARY oodialog dlgext_resizeMoveControl"

::method clearRect unguarded external "LIBRARY oodialog dlgext_clearRect"
::method clearWindowRect unguarded external "LIBRARY oodialog dlgext_clearWindowRect"
::method clearControlRect unguarded external "LIBRARY oodialog dlgext_clearControlRect"
::method redrawRect unguarded external "LIBRARY oodialog dlgext_redrawRect"
::method redrawWindowRect unguarded external "LIBRARY oodialog dlgext_redrawWindowRect"
::method redrawControl unguarded external "LIBRARY oodialog dlgext_redrawControl"
::method setForegroundWindow unguarded external "LIBRARY oodialog dlgext_setForgroundWindow"

::method drawButton unguarded external "LIBRARY oodialog dlgext_drawButton"
::method createBrush unguarded external "LIBRARY oodialog dlgext_createBrush"

::method redrawWindow unguarded
   use arg hwnd
   return .Window~new(hwnd)~redraw

-- DEPRECATED START
::method combineELwithSB  -- Use UpDown control, this method works very poorly
   use strict arg elid, sbID, step = 0, poscode = 0
   sb = self~newScrollBar(sbID)
   if sb == .nil then return -1
   pos = self~getEditData(elid)
   if \ pos~DataType("W") then return -1

   r = sb~getRange
   if .SystemErrorCode <> 0 then return -1

   if arg(4, "E") then do
       sbc = .DlgUtil~loWord(poscode)
       if sbc = 0 & step > 0 then step = -step
       else if sbc = 1 & step < 0 then step = +step
   end

   if step > 0 then do
      if pos < r~max then pos = pos + step
   end
   else if step < 0 then do
      if pos > r~min then pos = pos + step
   end
   else if arg(4, 'E') then do
      /* calc the position returned by message */
      pos = .DlgUtil~hiWord(poscode)
   end
   sb~setPos(pos)
   self~setEditData(elid, pos)
   return 0

::method connectAnimatedButton
   forward message "INSTALLANIMATEDBUTTON"
::method connectBitmapButton
   forward message "INSTALLBITMAPBUTTON"
::method clearButtonRect unguarded
   forward message 'CLEARCONTROLRECT'
::method freeButtonDC unguarded
   forward message 'FREECONTROLDC'
::method getButtonDC unguarded
   forward message 'GETCONTROLDC'
::method getButtonRect unguarded -- old method returns coordinates as a string
   forward message "GETCONTROLRECT" continue
   rect = result
   if \ rect~isA(.Rect) then return 1  -- mimic old behavior
   return rect~left rect~top rect~right rect~bottom

::method getWindowRect unguarded        -- Old method returns coordinates as a string.
   forward message "WINDOWRECT" continue
   rect = result
   return rect~left rect~top rect~right rect~bottom

::method moveItem unguarded      -- old method, this is not accurate
   use strict arg id, xPos, yPos, showOptions = ""
   p = .Point~new(trunc(xPos * self~factorX), trunc(yPos * self~factorY))
   return self~moveControl(id, p, showOptions)

::method redrawButton unguarded
   forward message 'REDRAWCONTROL'
::method resizeItem unguarded    -- old method, this is not accurate
   use strict arg id, width, height, showOptions = ""
   s = .Size~new(trunc(width * self~factorX), trunc(height * self~factorY))
   return self~resizeControl(id, s, showOptions)

::method scrollInButton unguarded
   forward message 'SCROLLINCONTROL'
::method setItemFont unguarded
   forward message 'SETCONTROLFONT'
::method setItemColor
   forward message "SETCONTROLCOLOR"
::method setItemSysColor
   forward message "SETCONTROLSYSCOLOR"
::method writeToButton unguarded
   forward message "WRITETOCONTROL"

-- END DEPRECATED


/******************************************************************************/
/* Bitmap extensions */

::method installBitmapButton external "LIBRARY oodialog dlgext_installBitmapButton"
::method changeBitmapButton unguarded external "LIBRARY oodialog dlgext_changeBitmapButton"
::method getBitmapPosition unguarded external "LIBRARY oodialog dlgext_getBitmapPosition"
::method setBitmapPosition unguarded external "LIBRARY oodialog dlgext_setBitmapPosition"
::method getBitmapSize unguarded external "LIBRARY oodialog dlgext_getBitmapSize"
::method getBitmapSizeX unguarded external "LIBRARY oodialog dlgext_getBitmapSize"
::method getBitmapSizeY unguarded external "LIBRARY oodialog dlgext_getBitmapSize"
::method drawBitmap unguarded external "LIBRARY oodialog dlgext_drawBitmap"

::method scrollText unguarded external "LIBRARY oodialog dlgext_scrollText"
::method scrollInControl unguarded external "LIBRARY oodialog dlgext_scrollText"

::method displaceBitmap unguarded external "LIBRARY oodialog dlgext_setBitmapPosition"
::method getBmpDisplacement unguarded
   use strict arg id
   pos = .Point~new
   if self~getBmpPosition(id, pos) then return pos~x pos~y
   else return -1

-- This method will add a method that will be started automatically and run concurrently when
-- the dialog is executed. That is the  method 'InClass'~'MethodName' will be started, when
-- the dialog receives the message 'execute' or execute async. You can use this method to animate
-- buttons.
::method addAutoStartMethod
   use arg inClass = (self), methodName, parameters
   self~automaticMethods~push(inClass)
   if arg(2,"E") then self~automaticMethods~push(methodName)
   if arg(3,"E") then self~automaticMethods~push(parameters)

-- Install an animated button and run it concurrently to the main activity.
--
-- The only way to get the bitmap(s) into the bitmap table is through this
-- method.  Therefore msgToRaise has to be optional.  The empty string will
-- eventually cause the bitmaps to be added to the bitmap table and the addition
-- of a method being added to the message table will be skipped.
::method installAnimatedButton
   use arg buttonID, msgToRaise = "", autoClass = (.AnimatedButton), bmpFrom, bmpTo = 0, moveX, moveY,   -
           sizeX, sizeY, delay, xNow = 0, yNow = 0

   -- Note documentation for bmpfrom, it is *not* a bitmap handle.
   if arg(5, "o") | \ bmpFrom~datatype("N") then
       ret = self~installBitmapButton(buttonID, msgToRaise, .local[bmpFrom][1])
   else
       ret = self~installBitmapButton(buttonID, msgToRaise, bmpFrom)

   if ret <> 0 then return ret

   if arg(8, "O") then sizeX = self~getBitmapSizeX(buttonID)
   if arg(9, "O") then sizeY = self~getBitmapSizeY(buttonID)

   self~addAutoStartMethod(autoClass, "RUN", buttonID || "," || bmpFrom ||"," || bmpTo ||"," || moveX    -
     || "," || moveY || "," || sizeX || "," || sizeY || "," || delay || "," || xNow || "," || yNow)

-- Draw the bitmap step by step.
::method dimBitmap unguarded external "LIBRARY oodialog dlgext_dimBitmap"

-- This method moves the rectangle within a button.  TODO be sure can take a .Rect for arg
::method scrollButton unguarded external "LIBRARY oodialog dlgext_scrollButton"

-- Scroll a bitmap from one position to another within a button.
::method scrollBitmapFromTo unguarded
   use arg id, fromX, fromY, toX, toY, stepX = 0, stepY = 0, delay = 0, displace = .true

   xl = self~getBitmapSizeX(id)
   yl = self~getBitmapSizeY(id)

   if xl <= 0 | yl <= 0 then return 1
   if stepX = 0 & stepY = 0 then return 1

   curX=fromx
   curY=fromy
   if (stepx > 0) then cursx = -curX; else cursx = 0
   if (stepy > 0) then cursy = -curY; else cursy = 0
   if (cursx > xl) then cursx = xl
   if (cursy > yl) then cursy = yl

   button = self~newPushButton(id)
   if button == .nil then return -1
   hwnd = button~hwnd

   parse value self~getWindowRect(hwnd) with r.left r.top r.right r.bottom
   r.right = r.right - r.left
   r.bottom = r.bottom - r.top
   drawx = 1
   drawy = 1

   if (stepx >= 0) then do
      left = max(fromx, 0)
      lenx = xl - cursx
   end
   else do
      left = fromx
      lenx = min(r.right-fromx, xl)
   end
   if (stepy >= 0) then do
      top = max(fromy, 0)
      leny = yl - cursy
   end
   else do
      top = fromy
      leny = min(r.bottom-fromy, yl)
   end

   self~drawBitmap(hwnd, id, left, top, cursx, cursy, lenx, leny)
   if (stepx < 0) then cursx = min(lenx, xl); else cursx = cursx-stepx;
   if (stepy < 0) then cursy = min(leny, yl); else cursy = cursy-stepy;

   worktodo = 1
   if (delay > 0) then timer = winTimer("START", delay); else timer = 0
   do while worktodo = 1

      sleft = curX
      srgt = curX+xl
      if srgt > r.right then srgt = r.right
      if sleft < 0 then sleft = 0

      s_top = curY
      sbot = curY+yl
      if sbot > r.bottom-stepy then sbot = r.bottom-stepy
      if s_top < 0 then s_top = 0

      ret = button~scroll(stepx, stepy, trunc(sleft), trunc(s_top), trunc(srgt), trunc(sbot))
      if ret = 1 then do
         if (timer \== 0) then ret = winTimer("STOP", timer)
         return 1
      end

      if (stepx < 0) then left = r.right + stepx; else left = curX
      rgt = curX+xl

      if rgt > r.right then rgt = r.right
      if left < 0 then left = 0

      if (stepy < 0) then top = r.bottom+stepy; else top = curY
      bot = curY+yl
      if bot > r.bottom then bot = r.bot
      if top < 0 then top = 0

      if stepx \= 0 & drawx=1 then self~drawBitmap(hwnd, id, left, top, cursx, cursy, abs(stepx), yl)
      if stepy \= 0 & drawy=1 then self~drawBitmap(hwnd, id, left, top, cursx, cursy, xl, abs(stepy))
      if (timer \== 0) then ret = winTimer("WAIT", timer)

      drawx = 0
      if (stepx <= 0) then do
         if cursx < xl then do
            cursx = cursx - stepx
            if cursx < xl then drawx = 1
         end
      end
      else do
         if cursx > 0 then do
            cursx = cursx - stepx
            if cursx > 0 then drawx = 1
         end
      end
      curX = curX + stepx

      drawy = 0
      if (stepy <= 0) then do
         if cursy < yl then do
            cursy = cursy - stepy
            if cursy < yl then drawy = 1
         end
      end
      else do
         if cursy > 0 then do
            cursy = cursy - stepy
            if cursy > 0 then drawy = 1
         end
      end
      curY = curY + stepy

                 /* so repaint will draw the cursor at the current position */
      if displace then self~setBitmapPosition(id, trunc(curX), trunc(curY));

      worktodo = 0
      if (stepx>0) & (curX+stepx <= tox) then worktodo = 1
      if (stepy>0) & (curY+stepy <= toy) then worktodo = 1
      if (stepx<0) & (curX+stepx >= tox) then worktodo = 1
      if (stepy<0) & (curY+stepy >= toy) then worktodo = 1
   end
   if (timer \== 0) then ret = winTimer("STOP", timer)
   self~setBitmapPosition(id, tox, toy);
   self~redrawButton(id,0)
   return 0


/******************************************************************************/
/* Graphics and drawing extensions */

::method writeToWindow unguarded external "LIBRARY oodialog dlgext_writeToWindow"

::method writeToControl unguarded
   argArray = arg(1,"A")
   argArray[1] = self~getControlHandle(arg(1))
   forward message 'writeToWindow' arguments (argArray)

::method getWindowDC unguarded external "LIBRARY oodialog dlgext_getWindowDC"
::method getControlDC unguarded
   use strict arg id
   return self~getWindowDC(self~getControlHandle(id))

::method freeWindowDC unguarded external "LIBRARY oodialog dlgext_freeWindowDC"
::method freeControlDC unguarded
   use strict arg id, dc
   hwnd = self~getControlHandle(id)
   return self~freeWindowDC(hwnd, dc)



/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*\
  These menu bar methods are needed to provide backward compatibility for the
  deprecated menu methods.  The Rexx programmer is *strongly* discouraged from
  using them.  If the deprecated methods are removed, these will be removed with
  them.

  In addition, it is highly likely that the results will be unpredictable.

  To obtain the menuBar attached to the dialog, use the getMenuBar() method.
\* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/

::attribute menuBar private
::attribute isLinked private

::method linkMenu
  use strict arg menu

  signal on syntax

  if \ menu~isA(.MenuBar) then raise syntax 93.948 array(1, "MenuBar")

  oldMenu = self~menuBar
  self~menuBar = menu
  self~isLinked = .true
  return oldMenu

syntax:
  c = condition('O')
  if c~traceBack~isA(.List) then c~traceBack~empty
  raise propagate

::method unlinkMenu
  menu = self~menuBar
  self~menuBar = .nil
  self~isLinked = .false
  return menu

-- Deprecated to end of file.
::method captureMouse
  use strict arg
  mouse = .Mouse~new(self)
  return mouse~capture

::method getMouseCapture
  use strict arg
  mouse = .Mouse~new(self)
  return mouse~getCapture

::method isMouseButtonDown
  use strict arg whichButton = "LEFT"
  mouse = .Mouse~new(self)
  return mouse~isButtonDown(whichButton)

::method releaseMouseCapture
  use strict arg
  mouse = .Mouse~new(self)
  return mouse~releaseCapture

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*\
  The following menu bar methods are deprecated, instead, use the Menu classes
  directly.
\* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/

::method enableMenuItem unguarded
    use strict arg id

    signal on syntax

    if self~menuBar == .nil then raise syntax 93.900 array("there is no MenuBar attached to this dialog")
    if self~menuBar~isA(.UserMenuBar), \self~menuBar~isComplete then raise syntax 93.900 array("the UserMenuBar is not complete")
    return self~menuBar~enable(id)

syntax:
  c = condition('O')
  if c~traceBack~isA(.List) then c~traceBack~empty
  raise propagate

::method disableMenuItem unguarded
    use strict arg id

    signal on syntax

    if self~menuBar == .nil then raise syntax 93.900 array("There is no MenuBar attached to this dialog")
    if self~menuBar~isA(.UserMenuBar), \self~menuBar~isComplete then raise syntax 93.900 array("the UserMenuBar is not complete")
    return self~menuBar~disable(id)

syntax:
  c = condition('O')
  if c~traceBack~isA(.List) then c~traceBack~empty
  raise propagate

::method checkMenuItem unguarded
    use strict arg id

    signal on syntax

    if self~menuBar == .nil then raise syntax 93.900 array("There is no MenuBar attached to this dialog")
    if self~menuBar~isA(.UserMenuBar), \self~menuBar~isComplete then raise syntax 93.900 array("the UserMenuBar is not complete")
    return self~menuBar~check(id)

syntax:
  c = condition('O')
  if c~traceBack~isA(.List) then c~traceBack~empty
  raise propagate

::method uncheckMenuItem unguarded
    use strict arg id

    signal on syntax

    if self~menuBar == .nil then raise syntax 93.900 array("There is no MenuBar attached to this dialog")
    if self~menuBar~isA(.UserMenuBar), \self~menuBar~isComplete then raise syntax 93.900 array("the UserMenuBar is not complete")
    return self~menuBar~uncheck(id)

syntax:
  c = condition('O')
  if c~traceBack~isA(.List) then c~traceBack~empty
  raise propagate

::method grayMenuItem unguarded
    use strict arg id

    signal on syntax

    if self~menuBar == .nil then raise syntax 93.900 array("There is no MenuBar attached to this dialog")
    if self~menuBar~isA(.UserMenuBar), \self~menuBar~isComplete then raise syntax 93.900 array("the UserMenuBar is not complete")
    return self~menuBar~gray(id)

syntax:
  c = condition('O')
  if c~traceBack~isA(.List) then c~traceBack~empty
  raise propagate

::method setMenuItemRadio unguarded
    use strict arg idstart, idend, idset

    signal on syntax

    if self~menuBar == .nil then raise syntax 93.900 array("There is no MenuBar attached to this dialog")
    if self~menuBar~isA(.UserMenuBar), \self~menuBar~isComplete then raise syntax 93.900 array("the UserMenuBar is not complete")
    return self~menuBar~checkRadio(idstart, idend, idset)

syntax:
  c = condition('O')
  if c~traceBack~isA(.List) then c~traceBack~empty
  raise propagate

::method getMenuItemState unguarded
    use strict arg id

    signal on syntax

    if self~menuBar == .nil then raise syntax 93.900 array("There is no MenuBar attached to this dialog")
    if self~menuBar~isA(.UserMenuBar), \self~menuBar~isComplete then raise syntax 93.900 array("the UserMenuBar is not complete")
    return self~menuBar~getItemState(id)

syntax:
  c = condition('O')
  if c~traceBack~isA(.List) then c~traceBack~empty
  raise propagate

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*\
  End deprecated menu bar methods.
\* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/

/**
 * Windows Dialog Interface for Open Object Rexx (ooRexx.)
 *
 * The Dynamic Dialog Class.  This class is the foundation for creating a dialog
 * template in memory.
 */
::class 'DynamicDialog' mixinclass Object public

::constant STATIC_ID  -1

::method init class external "LIBRARY oodialog dyndlg_init_cls"

-- Documented "internal use only" in 3.2.0 - Do not document.
::attribute basePtr get private external "LIBRARY oodialog dyndlg_getBasePtr"
::attribute basePtr set private external "LIBRARY oodialog dyndlg_setBasePtr"

-- Documented "internal use only" in 3.2.0 - Do not document.
::attribute activePtr get private external "LIBRARY oodialog dyndlg_getActivePtr"
::attribute activePtr set private external "LIBRARY oodialog dyndlg_setActivePtr"

-- Documented "internal use only" in 3.2.0 - Do not document.
::attribute dialogItemCount get private external "LIBRARY oodialog dyndlg_getDialogItemCount"
::attribute dialogItemCount set private external "LIBRARY oodialog dyndlg_setDialogItemCount"

::method dynamicInit private external "LIBRARY oodialog dyndlg_dynamicInit"
::method stop private external "LIBRARY oodialog dyndlg_stop"

::method startParentDialog private external "LIBRARY oodialog dyndlg_startParentDialog"
::method startChildDialog private external "LIBRARY oodialog dyndlg_startChildDialog"

-- This method should be over-ridden in subclasses and provides the opportunity for the subclass to
-- add dialog controls to the dialog template.
::method defineDialog
   return 0

::method create external "LIBRARY oodialog dyndlg_create"
::method createCenter
   arga = arg(1,"A")
   newarg = .array~new(arg()+2)
   do i = arg() to 1 by -1; if arga~hasindex(i) = 1 then newarg[i+2] = arga[i]; end   /* shift arguments up by 2 */
   -- Let OS center the dialog.
   if \ newarg~hasindex(6) then newarg[6] = "CENTER"
   else newarg[6] = newarg[6] || " CENTER"
   -- When dialog has centered style, the OS will ignore the x, y co-ordinates
   newarg[1] = 0
   newarg[2] = 0
   forward message "create" arguments (newarg)

::method createStatic external "LIBRARY oodialog dyndlg_createStatic"
::method createStaticText external "LIBRARY oodialog dyndlg_createStaticText"
::method createStaticImage external "LIBRARY oodialog dyndlg_createStaticImage"
::method createStaticFrame external "LIBRARY oodialog dyndlg_createStaticFrame"
::method createWhiteRect external "LIBRARY oodialog dyndlg_createStaticFrame"
::method createGrayRect external "LIBRARY oodialog dyndlg_createStaticFrame"
::method createBlackRect external "LIBRARY oodialog dyndlg_createStaticFrame"
::method createWhiteFrame external "LIBRARY oodialog dyndlg_createStaticFrame"
::method createGrayFrame external "LIBRARY oodialog dyndlg_createStaticFrame"
::method createBlackFrame external "LIBRARY oodialog dyndlg_createStaticFrame"
::method createEtchedHorizontal external "LIBRARY oodialog dyndlg_createStaticFrame"
::method createEtchedVertical external "LIBRARY oodialog dyndlg_createStaticFrame"
::method createEtchedFrame external "LIBRARY oodialog dyndlg_createStaticFrame"

::method createPushButton external "LIBRARY oodialog dyndlg_createPushButton"
::method createRadioButton external "LIBRARY oodialog dyndlg_createRadioButton"
::method createCheckBox external "LIBRARY oodialog dyndlg_createRadioButton"
::method createGroupBox external "LIBRARY oodialog dyndlg_createGroupBox"

-- The optional msgToRaise arg can be the name of a method to invoke when the
-- button is pushed.  The empty string  signals the implementing code to skip
-- adding a method to the message table and just add the bitmaps.
::method createBitmapButton
   use strict arg id, x, y, cx = 0, cy = 0, opts = "", text = "", msgToRaise = "", bmp, focus = "", sel = "", disabl = ""
   if \ self~hasMethod('INSTALLBITMAPBUTTON') then return -3
   opts = opts~translate || " OWNER"
   if focus = "" & sel = "" & opts~wordpos("FRAME") = 0 & opts~wordpos("TAB") = 0 then opts = opts || " NOTAB"
   ret = self~createPushButton(id, x, y, cx, cy, opts, text)
   if ret <> 0 then return ret
   return self~installBitmapButton(id, msgToRaise~space(0), bmp, focus, sel, disabl, opts)


::method createComboBox external "LIBRARY oodialog dyndlg_createComboBox"
::method createDateTimePicker external "LIBRARY oodialog dyndlg_createNamedControl"
::method createEdit external "LIBRARY oodialog dyndlg_createEdit"
::method createListBox external "LIBRARY oodialog dyndlg_createListBox"
::method createListView external "LIBRARY oodialog dyndlg_createNamedControl"
::method createMonthCalendar external "LIBRARY oodialog dyndlg_createNamedControl"
::method createPasswordEdit external "LIBRARY oodialog dyndlg_createEdit"
::method createProgressBar external "LIBRARY oodialog dyndlg_createProgressBar"
::method createReBar external "LIBRARY oodialog dyndlg_createNamedControl"
::method createStatusBar external "LIBRARY oodialog dyndlg_createNamedControl"
::method createScrollBar external "LIBRARY oodialog dyndlg_createScrollBar"
::method createTab external "LIBRARY oodialog dyndlg_createNamedControl"
::method createToolBar external "LIBRARY oodialog dyndlg_createNamedControl"
::method createTrackBar external "LIBRARY oodialog dyndlg_createNamedControl"
::method createTreeView external "LIBRARY oodialog dyndlg_createNamedControl"
::method createUpDown external "LIBRARY oodialog dyndlg_createNamedControl"

::method createRadioButtonGroup
   arr = arg(1,"A")
   if \ arr~hasindex(6) then arr[6] = ""
   arr[8] = "R"
   forward message "createRBCBGroup" Arguments (arr)

::method createCheckBoxGroup
   arr = arg(1,"A")
   if \ arr~hasindex(6) then arr[6] = ""
   arr[8] = "C"
   forward message "createRBCBGroup" Arguments (arr)

::method createRBCBGroup private
   use arg startid, x, y, cx, inp, opts = "", idstat = (self~STATIC_ID), kind

   if self~activePtr = 0 then return -2
   startid = self~checkID(startid)
   if startid < 0 then return startid
   if arg(4, 'o') = 1 then cx = 0
   parse var inp rb inp
   size = self~getTextSizeDu(rb)
   len = size~width
   stepy = size~height
   lastlen = len; oldy = stepy; stepy = trunc(stepy * 1.5)
   opts = opts~translate
   nob = opts~wordpos("NOBORDER")
   if nob = 0 then my = y + oldy; else my = y
   newopts = opts~changestr("NOBORDER","")
   if cx \= 0 then len = cx-20

   i = 0
   do while rb \= ""
      if kind = "R" then do
          if i = 0 then self~createRadioButton(startid + i, x + 4, my, len + 12, stepy, newopts || " GROUP", rb)
          else self~createRadioButton(startid + i, x + 4, my, len + 12, stepy, newopts, rb)
      end
      else do
          self~createCheckBox(startid + i, x + 4, my, len + 12, stepy, newopts, rb)
      end
      my = my + stepy; i = i + 1
      parse var inp rb inp
      if rb \== '', cx = 0 then do
         s = self~getTextSizeDu(rb)
         len = s~width
         if len > lastlen then lastlen = len
      end
   end
   if cx \= 0 then LastLen = cx-20
   size = .Size~new(lastlen+20, my-y+trunc(oldy / 2))
   if nob = 0 then self~createGroupBox(idstat, x, y, size~width, size~height, newopts, "")
   return size

::method createEditInput
   use strict arg id, x, y, cx1 = 0, cx2, cy = 0, text, opts = "", idstat = (self~STATIC_ID), attributeName = ""
   if self~activePtr = 0 then return -2
   id = self~checkID(id)
   if id < 0 then return id
   if attributeName == "" then attributeName = text
   if cy = 0 | cx1 = 0 then do
      size = self~getTextSizeDu(text)
      if cy = 0 then cy = size~height + 4
      if cx1 = 0 then cx1 = size~width + 4
   end
   opts = opts~translate
   ret = self~createStaticText(idstat, x, y+2, cx1, cy, opts, text)
   if ret == 0 then ret = self~createEdit(id, x+cx1+1, y, cx2, cy, opts, attributeName)
   return ret


::method createEditInputGroup
   use strict arg startid, x, y, cx1 = 0, cx2, inp, opts = "", idstat = (self~STATIC_ID)
   parse var inp rb inp

   if self~activePtr = 0 then return -2
   startid = self~checkID(startid)
   if startid < 0 then return startid
   if arg(4, 'o') = 1 then cx1 = 0
   count = 0; ll = 0
   do while rb \= ""
      count = count + 1
      data.count = rb
      if cx1 = 0 then do
         size = self~getTextSizeDu(rb)
         if size~width > ll then ll = size~width
      end
      parse var inp rb inp
   end
   if cx1 = 0 then cx1 = ll+4
   is = idstat

   s = self~getTextSizeDu("Tg")
   stepy = s~height
   opts = opts~translate
   nob = opts~wordpos("NOBORDER")
   if nob = 0 then my = y + trunc(stepy * 1.25); else my = y
   newopts = opts~changestr("NOBORDER", "")
   do i=1 to count
      self~createEditInput(startid + i -1, x+4, my, cx1-4, cx2-6, stepy+4, data.i, newopts, is)
      if is \= -1 then is = is + 1
      my = my + trunc(stepy * 2.25)
   end
   if nob = 0 then return self~createGroupBox(is, x, y, cx1+cx2, my-y, newopts, "")
   else return 0


::method createEditInputStem
   use strict arg startid, x, y, cx1 = 0, cx2, inp., opts = "", idstat = (self~STATIC_ID)

   if self~activePtr = 0 then return -2
   startid = self~checkID(startid)
   if startid < 0 then return startid
   count = 0; ll = 0
   do while var("inp."count+1) = 1
      count = count + 1
      if cx1 = 0 then do
         s = self~getTextSizeDu(inp.count)
         if s~width > ll then ll = s~width
      end
   end
   if cx1 = 0 then cx1 = ll+4

   is = idstat
   s = self~getTextSizeDu("Tg")
   stepy = s~height

   opts = opts~translate
   nob = opts~wordpos("NOBORDER")
   if nob = 0 then my = y + trunc(stepy * 1.25); else my = y
   newopts = opts~changestr("NOBORDER", "")
   do i=1 to count
      self~createEditInput(startid + i -1, x+4, my, cx1-4, cx2-6, stepy+4, inp.i, newopts, is)
      if is \= -1 then is = is + 2
      my = my + trunc(stepy * 2.25)
   end
   if nob = 0 then return self~createGroupBox(is, x, y, cx1+cx2, my-y, newopts, "")
   else return 0

::method createComboBoxInput
   use strict arg id, x, y, cx1 = 0, cx2, clines = 5, text, opts = "", idstat = (self~STATIC_ID), attributeName = ""

   if self~activePtr = 0 then return -2
   id = self~checkID(id)
   if id < 0 then return id
   if attributeName == "" then attributeName = text

   s = self~getTextSizeDu(text)
   cy = s~height + 4
   if cx1 = 0 then cx1 = s~width + 4
   opts = opts~translate
   ret = self~createStaticText(idstat, x, y, cx1, cy, opts, text)
   if ret == 0 then return self~createComboBox(id, x+cx1+2, y, cx2, cy*clines, opts, attributeName)
   else return ret

::method createCheckBoxStem
   arr = arg(1,"A")
   arr[11] = "C"
   if \ arr~hasindex(7) then arr[7] = ""
   forward message "createRBCBStem" Arguments (arr)

::method createRadioButtonStem
   arr = arg(1,"A")
   arr[11] = "R"
   if \ arr~hasindex(7) then arr[7] = ""
   forward message "createRBCBStem" Arguments (arr)

::method createRBCBStem private
   use arg startid, x, y, cxx, inp., max, opts = "", idstat, fn, fs, kind
   -- Note that font name and font size (fn, fs) are no longer used.  They are
   -- here for backwards compatibility.

   if self~activePtr = 0 then return -2
   startid = self~checkID(startid)
   if startid < 0 then return
   if arg(4, 'o') = 1 then cxx = 0
   count = 0; ll = 0
   do while var("inp."count+1) = 1
      count = count + 1
      if cxx = 0 then do
         s = self~getTextSizeDu(inp.count)
         if s~width > ll then ll = s~width
      end
   end
   if var("max") = 0 | max = 0 then max = count
   if cxx = 0 & max \= 1 then cx = ll+20; else cx = cxx
   if arg(8, 'o') = 1 then idstat = self~STATIC_ID
   s = self~getTextSizeDu("Tg")
   stepx = s~width
   oldy = s~height
   mx = 0; highy = 0
   opts = opts~translate
   nob = opts~wordpos("NOBORDER")
   if nob = 0 then do
      stepy = trunc(oldy * 1.5)
      my = y + oldy
      newopts = opts
   end
   else do
      stepy = oldy
      my = y
      newopts = delword(opts, nob, 1)
   end
   do i=1 to count
      if (i>1) & ((i-1)//max = 0) then do
         highy = my
         if nob = 0 then my = y + oldy; else my = y
         mx = mx + cx
      end
      if max=1 & cxx=0 then do
         s = self~getTextSizeDu(inp.i)
         cx = s~width + 24
      end
      if kind = "R" then do
         if i = 1 then tmpopts = newopts || " GROUP"; else tmpopts = newopts
         self~createRadioButton(startid + i - 1, x + mx + 4, my, cx - 8, stepy, tmpopts, inp.i)
      end
      else do
         self~createCheckBox(startid + i - 1, x + mx + 4, my, cx - 8, stepy, newopts, inp.i)
      end
      my = my + stepy
   end
   if highy = 0 then highy = my
   if nob = 0 then return self~createGroupBox(idstat, x, y, mx+cx, highy-y+(stepy % 2), newopts, "")
   else return 0

::method createPushButtonGroup
   use arg x, y, cx, cy, inp, bottom, opts = ""
   parse var inp bt bid bfnk newinp

   if self~activePtr = 0 then return -2
   if arg(6,"o") = 1 then bottom = 0
   if cx = 0 | arg(3,"o") = 1 then cx = 40
   if cy = 0 | arg(4,"o") = 1 then cy = 12

   opts = opts~translate
   do while bt \= ""
      if bt~pos("'") > 0 then parse var inp "'"bt"'" bid bfnk newinp
      else if bt~pos('"') > 0 then parse var inp '"'bt'"' bid bfnk newinp
      if bfnk = 0 then bfnk = ""
      self~createPushButton(bid, x, y, cx, cy, opts, bt, bfnk)
      n = opts~wordpos("DEFAULT")
      if n \= 0 then opts = opts~delword(n,1)
      if bottom = 0 then y = y + trunc(cy * 1.5); else x = x + trunc(cx * 1.25)
      inp = newinp
      parse var inp bt bid bfnk newinp
   end
   return 0


::method createPushButtonStem external "LIBRARY oodialog dyndlg_createPushButtonStem"
::method createOkCancelRightBottom
   return self~createPushButtonGroup(self~sizeX-95, self~sizeY - 15,,, "&Ok 1 OK &Cancel 2 CANCEL", 1, "DEFAULT")

::method createOkCancelLeftBottom
   return self~createPushButtonGroup(5, self~sizeY - 15,,, "&Ok 1 OK &Cancel 2 CANCEL", 1, "DEFAULT")

::method createOkCancelRightTop
   return self~createPushButtonGroup(self~sizeX-45, 5,,, "&Ok 1 OK &Cancel 2 CANCEL", 0, " DEFAULT")

::method createOkCancelLeftTop
   return self~createPushButtonGroup(5, 5,,, "&Ok 1 OK &Cancel 2 CANCEL", 0, "DEFAULT")

::method addIconResource external "LIBRARY oodialog dyndlg_addIconResource"

-- Documented "internal use only" in 3.2.0 - Do not document.
::method startIt
   use arg icon = 0, modeless = .false
   if self~basePtr = 0 then return 0

   icon = self~resolveIconID(icon)
   if \ modeless~datatype('O') then modeless = .false

   if \ self~startParentDialog(icon, modeless) then return 0

   self~initDialog
   return self~dlgHandle


-- This method creates a dialog from a resource script file (usually with extension of '.rc'.)
-- It calls loadFrame() and loadItems() The argument 'loadOptions' can be one or more of:e
--    "CENTER"         : this will create the dialog on a centered position
--    "CONNECTBUTTONS" : automatically connect all push buttons to a method
--    "CONNECTRADIOS"  : automatically connect all raidio buttons to a method
--    "CONNECTCHECKS"  : automatically connect all check boxes to a method
::method load
   forward message "loadFrame" continue
   ret = result
   if ret == 0 then do
      forward message "loadItems" continue
      ret = result
   end
   else do
      self~stop
   end
   return ret



-- This method starts the in-memory dialog template using the specified resource script file.
-- It is usually called from the load() method.  The return was not documented prior to
-- 4.1.0, but it returned 0 for success and 1 for error.  Need to preserve that, I guess,
-- although .true and .false make much more sense.
--
-- We special case a .PropertySheetPage and return the dlg. stem so the dialog template
-- can be started correctly for DS_CONTROL dialogs.
::method loadFrame private
   use arg resfile, dialogid, options, expected

   if arg(4,"O") | expected = 0 then expected = 200
   if options~translate~wordpos("CENTER") > 0 then internopts = "CENTER "
   else internopts = ""

   file = SysSearchPath("PATH",resfile)
   f = .stream~new(file)
   op = f~open(read)
   if op \= "READY:" then do
      say "Resource file not found -->" resfile "("op")"
      return 1
   end

   global = .constDirUsage == 'use only'
   found = 0; n = 0
   fl = f~lines
   do while found = 0
      do while n = 0 & fl > 0
         s = f~linein; fl = fl -1
         select
            when s~wordpos("DIALOG ") > 0 then n = s~wordpos("DIALOG ")
            when s~wordpos("DIALOGEX ") > 0 then n = s~wordpos("DIALOGEX ")
            when s~wordpos("ICON") = 2 then do
               -- ICON RESOURCE statement as opposed to an ICON CONTROL statement.
               -- filename could have spaces and *should* be in quotes.
               parse var s nameID ic fileName
               self~addIconResource(nameID, fileName)
            end
            when s~wordpos("#define") > 0 then do
               s = s~translate(" ", "9"x)
               parse var s "#define " symb iid .
               if global then .constDir[symb] = iid
               else self~constDir[symb~space(0)~translate] = iid
            end
            otherwise
               nop
         end
         -- End select
      end
      if (self~checkfile(f) = 1) then return 1
      if arg(2,'O') | dialogid = "DIALOGID" | dialogid = '' then found = 1
      else do
         foundID = s~word(n-1)~translate
         if foundID = dialogid~translate then found = 1
         else if self~checkID(foundID) = dialogid then found = 1
         else if foundID = self~checkID(dialogid~translate) then found = 1
         else n = 0
      end
   end

   n = s~Pos(",")
   parse var s prev "," dlg.y "," dlg.w "," dlg.h
   dlg.x = s~substr(n-3,3)
   if dlg.x~datatype('N') = 0 then dlg.x = s~substr(n-2,2)

   s = f~linein; fl = fl -1
   do while s~wordpos("STYLE ") = 0 & fl > 0
      s = f~linein; fl = fl -1
   end
   if (self~checkfile(f) = 1) then return 1
   parse var s prev dlg.style
   dlg.style = dlg.style~translate(" ", "|")

   internopts = internopts || self~getRCStyle(dlg.style, "DLG")

   dlg.title = ""
   dlg.fsize = ""
   dlg.font = ""

   s = f~linein; fl = fl -1
   do while s~wordpos("CAPTION ") = 0 & s~wordpos("FONT ") = 0 & fl > 0
      s = f~linein; fl = fl -1
   end
   if (self~checkfile(f) = 1) then return 1
   if s~wordpos("CAPTION ") > 0 then do
      parse var s prev '"'dlg.title'"'
      s = f~linein; fl = fl -1
      do while s~wordpos("FONT ") = 0 & fl > 0
         s = f~linein; fl = fl -1
      end
      if fl > 0 then do
         parse var s prev dlg.fsize "," '"'dlg.font'"'
      end
   end
   else do
      parse var s prev dlg.fsize "," '"'dlg.font'"'
   end

   -- Now read to the end of the file to pick up any additional icon resource
   -- or define statements.
   do while fl > 0
      s = f~linein; fl = fl -1
      select
         when s~wordpos("ICON") = 2 then do
            parse var s nameID ic fileName
            self~addIconResource(nameID, fileName)
         end
         when s~wordpos("#define") > 0 then do
            s = s~translate(" ", "9"x)
            parse var s "#define " symb iid .
            if global then .constDir[symb] = iid
            else self~constDir[symb~space(0)~translate] = iid
         end
         otherwise
            nop
      end
      -- End select
   end
   f~close

   if dlg.title == "" then internopts ||= " NOBORDER"

   if self~isA(.PropertySheetPage) then return self~startTemplate(dlg.w, dlg.h, dlg.title, dlg.font, dlg.fsize, expected)

   if self~create(dlg.x, dlg.y, dlg.w, dlg.h, dlg.title, internopts,, dlg.font, dlg.fsize, expected) then return 0
   else return 1

-- This method creates the dialog's controls from a resource script file. It is usually called by the load() method.
-- Although its return was not documented prior to 4.1.0, it has returned 0 for success and non-zero for failure.
::method loadItems private
   use arg resfile, dialogid, loadOptions
   if self~activePtr = 0 then return -2

   file = SysSearchPath("PATH",resfile)
   f = .stream~new(file)
   op = f~open(read)
   if op \= "READY:" then do
      say "Resource file not found --> " op
      return 1
   end

   global = .constDirUsage == 'use only'
   if arg(3, "O") then loadOptions = ""; else loadOptions = loadOptions~translate
   found = 0; n = 0
   fl = f~lines
   do while found = 0 & fl > 0
      do while n = 0 & fl > 0
         s = f~linein; fl = fl - 1
         -- This seems redundent, #defines were probably already caught in loadFrame()
         if s~wordpos("#define") > 0 then do
             s = s~translate(" ", "9"x)
             parse var s "#define " symb iid .
             if global then .constDir[symb] = iid
             else self~constDir[symb~space(0)~translate] = iid
         end
         n = s~wordpos("DIALOG")
         if n = 0 then n = s~wordpos("DIALOGEX")
      end
      if self~checkfile(f)=1 then return 1
      if arg(2, 'O') | dialogid = "DIALOGID" | dialogid = '' then found = 1
      else do
         foundID = s~word(n-1)~translate
         if foundID = dialogid~translate then found = 1
         else if self~checkID(foundID) = dialogid then found = 1
         else if foundID = self~checkID(dialogid~translate) then found = 1
         else n = 0
      end
   end

   s = f~linein; fl = fl - 1
   do while s~wordpos("BEGIN") = 0 & s~pos("{") = 0 & fl > 0
       s = f~linein; fl = fl - 1
   end
   if self~checkfile(f)=1 then return 1

   self~processingLoad = 1
   do while fl > 0 & s~wordpos("END") = 0 & s~pos("}") = 0
      s = f~linein; fl = fl - 1
      if s~wordpos("END") > 0 | s~pos("}") > 0 then leave;

      if s~wordpos("CONTROL") > 0 then do
         parse var s type '"'name'"' "," id "," class "," style "," x "," y "," w "," h "," extStyle
         opts = ""
         id = id~strip
         class = class~strip~translate
         style = style~translate(" ", "|")
         extStyle = extStyle~translate(" ", "|")
         select
            when class = '"BUTTON"' | class = WC_BUTTON then do
               if style~wordpos("BS_AUTORADIOBUTTON") > 0 | style~wordpos("BS_RADIOBUTTON") > 0 then
                  self~createRadioButton(id, x, y, w, h, self~getRCStyle(style, "BTN", "R"), name, , loadOptions)
               else if style~wordpos("BS_AUTOCHECKBOX") > 0 | style~wordpos("BS_CHECKBOX") > 0 then
                  self~createCheckBox(id, x, y, w, h, self~getRCStyle(style, "BTN"), name, , loadOptions)
               else if style~wordpos("BS_GROUPBOX") > 0 then
                  self~createGroupBox(id, x, y, w, h, self~getRCStyle(style, "GB"), name)
               else if style~pos("BS_OWNERDRAW") = 0 & style~wordpos("BS_AUTO3STATE") > 0 then do
                  -- If not the owner draw flag and the 3state flag, it is a checkbox.
                  self~createCheckBox(id, x, y, w, h, self~getRCStyle(style, "BTN"), name, , loadOptions)
               end
               else do
                  self~createPushButton(id, x, y, w, h, self~getRCStyle(style, "BTN"), name, , loadOptions)
               end
            end

            when class = 'WC_COMBOBOX' | class = '"COMBOBOX"' then
               self~createComboBox(id, x, y, w, h, self~getRCStyle(style, "CB"), name)

            when class = 'DATETIMEPICK_CLASS' | class = '"SYSDATETIMEPICK32"' then
               self~createDateTimePicker(id, x, y, w, h, self~getNamedCtrlStyle(style, "DTP"), name)

            when class = 'WC_EDIT' | class = '"EDIT"' then
               self~createEdit(id, x, y, w, h, self~getRCStyle(style, "EDIT"), name)

            when class = 'WC_LISTBOX' | class = '"LISTBOX"' then
               self~createListBox(id, x, y, w, h, self~getRCStyle(style, "LB"), name)

            when class = 'WC_LISTVIEW' | class = '"SYSLISTVIEW32"' then
               self~createListView(id, x, y, w, h, self~getNamedCtrlStyle(style, "LIST"), name)

            when class = 'MONTHCAL_CLASS' | class = '"SYSMONTHCAL32"' then
               self~createMonthCalendar(id, x, y, w, h, self~getNamedCtrlStyle(style, "MONTH"), name)

            when class = 'PROGRESS_CLASS' | class = '"MSCTLS_PROGRESS32"' then
               self~createProgressBar(id, x, y, w, h, self~getNamedCtrlStyle(style, "PROGRESS"))

            when class = 'REBARCLASSNAME' then
               self~createReBar(id, x, y, w, h, self~getNamedCtrlStyle(style, "REBAR"), name)

            when class = 'WC_SCROLLBAR' | class = '"SCROLLBAR"' then
               self~createScrollBar(id, x, y, w, h, self~getRCStyle(style, "SB"))

            when class = '"STATIC"' | class = WC_STATIC then do
               opts = self~getRCStyle(style, "ST")
               select
                  when style~wordpos("SS_LEFT") > 0 then
                     self~createStaticText(id, x, y, w, h, opts, name)
                  when style~wordpos("SS_RIGHT") > 0 then
                     self~createStaticText(id, x, y, w, h, opts || " RIGHT", name)
                  when style~wordpos("SS_CENTER") > 0 then
                     self~createStaticText(id, x, y, w, h, opts || " CENTER", name)
                  when style~wordpos("SS_SIMPLE") > 0 then
                     self~createStaticText(id, x, y, w, h, opts || " SIMPLE", name)
                  when style~wordpos("SS_LEFTNOWORDWRAP") > 0 then
                     self~createStaticText(id, x, y, w, h, opts || " LEFTNOWRAP", name)
                  when style~wordpos("SS_WHITERECT") > 0 then
                     self~createWhiteRect(id, x, y, w, h, opts)
                  when style~wordpos("SS_GRAYRECT") > 0 then
                     self~createGrayRect(id, x, y, w, h, opts)
                  when style~wordpos("SS_BLACKRECT") > 0 then
                     self~createBlackRect(id, x, y, w, h, opts)
                  when style~wordpos("SS_WHITEFRAME") > 0 then
                     self~createWhiteFrame(id, x, y, w, h, opts)
                  when style~wordpos("SS_GRAYFRAME") > 0 then
                     self~createGrayFrame(id, x, y, w, h, opts)
                  when style~wordpos("SS_BLACKFRAME") > 0 then
                     self~createBlackFrame(id, x, y, w, h, opts)
                  when style~wordpos("SS_ETCHEDFRAME") > 0 then
                     self~createEtchedFrame(id, x, y, w, h, opts)
                  when style~wordpos("SS_ETCHEDHORZ") > 0 then
                     self~createEtchedHorizontal(id, x, y, w, h, opts)
                  when style~wordpos("SS_ETCHEDVERT") > 0 then
                     self~createEtchedVertical(id, x, y, w, h, opts)
                  when style~wordpos("SS_BITMAP") > 0 then
                     self~createStaticImage(id, x, y, w, h, "BITMAP " || opts)
                  when style~wordpos("SS_ENHMETAFILE") > 0 then
                     self~createStaticImage(id, x, y, w, h, "METAFILE " || opts)
                  when style~wordpos("SS_ICON") > 0 then
                     self~createStaticImage(id, x, y, w, h, "ICON " || opts)
                  otherwise
                      ret = errorDialog("Static item ignored due to unknown static style option in:" || -
                                         '0d0a'x || f "("s")")
               end
            end

            when class = 'STATUSCLASSNAME' then
               self~createStatusBar(id, x, y, w, h, self~getNamedCtrlStyle(style, "STATUS"), name)

            when class = 'WC_TABCONTROL' | class = '"SYSTABCONTROL32"' then
               self~createTab(id, x, y, w, h, self~getNamedCtrlStyle(style, "TAB"), name)

            when class = 'TOOLBARCLASSNAME' then
               self~createToolBar(id, x, y, w, h, self~getNamedCtrlStyle(style, "TOOLBAR"), name)

            when class = 'TRACKBAR_CLASS' | class = '"MSCTLS_TRACKBAR32"' then
               self~createTrackBar(id, x, y, w, h, self~getNamedCtrlStyle(style, "SLIDER"), name)

            when class = 'WC_TREEVIEW' | class = '"SYSTREEVIEW32"' then
               self~createTreeView(id, x, y, w, h, self~getNamedCtrlStyle(style, "TREE"), name)

            when class = 'UPDOWN_CLASS' | class = '"MSCTLS_UPDOWN32"' then
               self~createUpDown(id, x, y, w, h, self~getNamedCtrlStyle(style, "UPDOWN"), name)

            otherwise do
               self~errorFile(f, s)
               return 1
            end
         end /* select 2*/
      end
      else do
         parse var s type '"'name'"' "," id "," x "," y "," w "," h "," style "," extStyle
         if id~space(0) = "" then parse var s type id "," x "," y "," w "," h "," style "," extStyle
         id = id~strip
         type = type~strip~translate
         style = style~translate(" ", "|")
         extStyle = extStyle~translate(" ", "|")

         select
            when type = "DEFPUSHBUTTON" | type = "PUSHBUTTON" then do
               if type~left(3) = ("DEF") then style = style || " | BS_DEFPUSHBUTTON"
               self~createPushButton(id, x, y, w, h, self~getRCStyle(style, "BTN"), name, , loadOptions)
            end

            when type = "EDITTEXT" then
               self~createEdit(id, x, y, w, h, self~getRCStyle(style, "EDIT"), name)

            when type = "LTEXT" | type = "CTEXT" | type = "RTEXT" then do
               opts = self~getRCStyle(style, "ST")
               if type = "CTEXT" then opts = opts || " CENTER";
               else if type = "RTEXT" then opts = opts || " RIGHT";
               else if style~wordpos("SS_LEFTNOWORDWRAP") > 0 then opts = opts || " LEFTNOWRAP";
               self~createStaticText(id, x, y, w, h, opts, name)
            end

            when type = "ICON" then do
               opts = self~getRCStyle(style, "ST")
               self~createStaticImage(id, x, y, w, h, "ICON " || opts)
            end

            when type = "GROUPBOX" then
               self~createGroupBox(id, x, y, w, h, self~getRCStyle(style, "GB"), name)

            when type = "COMBOBOX" then
               self~createComboBox(id, x, y, w, h, self~getRCStyle(style, "CB"), name)

            when type = "LISTBOX" then
               self~createListBox(id, x, y, w, h, self~getRCStyle(style, "LB"), name)

            when type = "SCROLLBAR" then
               self~createScrollBar(id, x, y, w, h, self~getRCStyle(style, "SB"))

            when type = "AUTORADIOBUTTON" | type = "RADIOBUTTON" then
               self~createRadioButton(id, x, y, w, h, self~getRCStyle(style, "BTN", "R"), name, , loadOptions)

            when type = "AUTOCHECKBOX" | type = "CHECKBOX" then
               self~createCheckBox(id, x, y, w, h, self~getRCStyle(style, "BTN"), name, , loadOptions)

            when type = "AUTO3STATE" then do
               -- Sometimes AUTO3STATE is used for an owner draw button.
               if style~pos("BS_OWNERDRAW") > 0 then do
                   -- With the owner draw flag, treat as a regular button.
                  self~createPushButton(id, x, y, w, h, self~getRCStyle(style, "BTN"), name, , loadOptions)
               end
               else do
                   -- Otherwise, (no owner draw flag,) treat as 3state.
                   self~createCheckBox(id, x, y, w, h, self~getRCStyle(style, "BTN") || " | BS_AUTO3STATE", name, , loadOptions)
               end
            end
            otherwise do
               self~errorFile(f, s)
               return 1
            end
         end /*select 1*/
      end
   end /* do while */
   f~close
   self~processingLoad = 0
   return 0

::method getRCStyle private
   use arg style, kind, spec_kind
   ret = ""
   if style~wordpos("NOT WS_VISIBLE") > 0 then ret = "HIDDEN"
   else if style~wordpos("WS_VISIBLE") > 0 then ret = "VISIBLE"
   if style~wordpos("WS_DISABLED") > 0 & style~wordpos("NOT WS_DISABLED") == 0 then ret = ret || " DISABLED"
   if style~wordpos("WS_GROUP") > 0 & style~wordpos("NOT WS_GROUP") == 0 then ret = ret || " GROUP"

   if kind = "DLG" then do
      if style~wordpos("DS_CENTER") > 0 then ret = ret ||" CENTER"
      if style~wordpos("DS_SYSMODAL") > 0 then ret = ret ||" SYSTEMMODAL"
      if style~wordpos("DS_MODALFRAME") = 0 then ret = ret ||" NOTMODAL"
      if style~wordpos("WS_SYSMENU") = 0 then ret = ret ||" NOMENU"
      if style~wordpos("WS_THICKFRAME") > 0 then ret = ret ||" THICKFRAME"
      if style~wordpos("WS_MINIMIZEBOX") > 0 | style~wordpos("WS_GROUP") > 0 then ret = ret ||" MINIMIZEBOX"
      if style~wordpos("WS_MAXIMIZEBOX") > 0 | style~wordpos("WS_TABSTOP") > 0  then ret = ret ||" MAXIMIZEBOX"
      if style~wordpos("WS_OVERLAPPED") > 0 then ret = ret ||" OVERLAPPED"
      if style~wordpos("WS_POPUP") > 0 then ret = ret ||" POPUP"
      if style~wordpos("DS_CONTROL") > 0 | style~wordpos("WS_CHILD") > 0  then ret = ret ||" CONTROL"
   end
   else if kind = "BTN" then do
       if style~wordpos("WS_OWNERDRAW") > 0 | style~wordpos("BS_OWNERDRAW") > 0 then ret = ret || " OWNER"
       if ret~wordpos("OWNER") = 0 then if style~wordpos("BS_AUTO3STATE") > 0 then ret = ret || " 3STATE"
       if style~wordpos("BS_DEFPUSHBUTTON") > 0 then ret = ret || " DEFAULT"
       if style~wordpos("BS_LEFTTEXT") > 0 | style~wordpos("BS_RIGHTBUTTON") > 0 then ret = ret || " LTEXT"
       if style~wordpos("BS_BITMAP") > 0 then ret = ret || " BITMAP"
       if style~wordpos("BS_ICON") > 0 then ret = ret || " ICON"
       if style~wordpos("BS_LEFT") > 0 then ret = ret || " LEFT"
       if style~wordpos("BS_RIGHT") > 0 then ret = ret || " RIGHT"
       if style~wordpos("BS_CENTER") > 0 then ret = ret || " HCENTER"
       if style~wordpos("BS_TOP") > 0 then ret = ret || " TOP"
       if style~wordpos("BS_BOTTOM") > 0 then ret = ret || " BOTTOM"
       if style~wordpos("BS_VCENTER") > 0 then ret = ret || " VCENTER"
       if style~wordpos("BS_PUSHLIKE") > 0 then ret = ret || " PUSHLIKE"
       if style~wordpos("BS_MULTILINE") > 0 then ret = ret || " MULTILINE"
       if style~wordpos("BS_NOTIFY") > 0 then ret = ret || " NOTIFY"
       if style~wordpos("BS_FLAT") > 0 then ret = ret || " FLAT"
       if style~wordpos("WS_BORDER") > 0 then ret = ret || " BORDER"
       if style~wordpos("NOT WS_TABSTOP") > 0 then ret = ret || " NOTAB"
       if spec_kind == "R" then do  /* radio buttons need explicit WS_TABSTOP to be tab stops */
           if style~wordpos("WS_TABSTOP") = 0 then ret = ret || " NOTAB"
       end
   end
   else if kind = "GB" then do
       if style~wordpos("BS_LEFT") > 0 then ret = ret || " LEFT"
       if style~wordpos("BS_RIGHT") > 0 then ret = ret || " RIGHT"
       if style~wordpos("BS_CENTER") > 0 then ret = ret || " CENTER"
       if style~wordpos("WS_BORDER") > 0 then ret = ret || " BORDER"
       if style~wordpos("WS_TABSTOP") > 0 then ret = ret || " TAB"
   end
   else if kind = "EDIT" then do
      if style~wordpos("ES_AUTOHSCROLL") > 0 then ret = ret || " AUTOSCROLLH"
      if style~wordpos("ES_AUTOVSCROLL") > 0 then ret = ret || " AUTOSCROLLV"
      if style~wordpos("ES_PASSWORD") > 0 then ret = ret || " PASSWORD"
      if style~wordpos("ES_MULTILINE") > 0 then ret = ret || " MULTILINE"
      if style~wordpos("ES_READONLY") > 0 then ret = ret || " READONLY"
      if style~wordpos("ES_WANTRETURN") > 0 then ret = ret || " WANTRETURN"
      if style~wordpos("ES_NOHIDESEL") > 0 then ret = ret || " KEEPSELECTION"
      if style~wordpos("ES_CENTER") > 0 then ret = ret || " CENTER"
      if style~wordpos("ES_RIGHT") > 0 then ret = ret || " RIGHT"
      if style~wordpos("ES_UPPERCASE") > 0 then ret = ret || " UPPER"
      if style~wordpos("ES_LOWERCASE") > 0 then ret = ret || " LOWER"
      if style~wordpos("ES_NUMBER") > 0 then ret = ret || " NUMBER"
      if style~wordpos("ES_OEMCONVERT") > 0 then ret = ret || " OEM"
      if style~wordpos("NOT WS_TABSTOP") > 0 then ret = ret || " NOTAB"
   end
   else if kind = "CB" then do
      if style~wordpos("CBS_SIMPLE") > 0 then ret = ret || " SIMPLE"
      if style~wordpos("CBS_DROPDOWNLIST") > 0 then ret = ret || " LIST"
      if style~wordpos("CBS_LOWERCASE") > 0 then ret = ret || " LOWER"
      if style~wordpos("CBS_SORT") > 0 then ret = ret || " SORT"
      if style~wordpos("CBS_AUTOHSCROLL") = 0 then ret = ret || " NOHSCROLL"
      if style~wordpos("CBS_NOINTEGRALHEIGHT") > 0 then ret = ret || " PARTIAL"
      if style~wordpos("CBS_DISABLENOSCROLL") > 0 then ret = ret || " DISABLENOSCROLL"
      if style~wordpos("CBS_UPPERCASE") > 0 then ret = ret || " DISABLENOSCROLL"
      if style~wordpos("WS_VSCROLL") > 0 then ret = ret || " VSCROLL"
      if style~wordpos("WS_HSCROLL") > 0 then ret = ret || " HSCROLL"
      if style~wordpos("WS_TABSTOP") = 0 then ret = ret || " NOTAB"
   end
   else if kind = "LB" then do
      if style~wordpos("LBS_USETABSTOPS") > 0 then ret = ret || " COLUMNS"
      if style~wordpos("LBS_STANDARD") > 0 then ret = ret|| " SORT"
      else if style~wordpos("LBS_SORT") > 0 then ret = ret|| " SORT"
      if style~wordpos("LBS_NOTIFY") > 0 then ret = ret || " NOTIFY"
      if style~wordpos("LBS_MULTIPLESEL") > 0 then ret = ret || " MULTI"
      if style~wordpos("LBS_MULTICOLUMN") > 0 then ret = ret || " MCOLUMN"
      if style~wordpos("LBS_NOINTEGRALHEIGHT") > 0 then ret = ret || " PARTIAL"
      if style~wordpos("LBS_DISABLENOSCROLL") > 0 then ret = ret || " SBALWAYS"
      if style~wordpos("LBS_WANTKEYBOARDINPUT") > 0 then ret = ret || " KEYINPUT"
      if style~wordpos("LBS_EXTENDEDSEL") > 0 then ret = ret || " EXTSEL"
      if style~wordpos("WS_TABSTOP") = 0 then ret = ret || " NOTAB"
   end
   else if kind = "ST" then do
       if style~wordpos("SS_CENTERIMAGE") > 0 then ret = ret || " CENTERIMAGE"
       if style~wordpos("SS_EDITCONTROL") > 0 then ret = ret || " EDITCONTROL"
       if style~wordpos("SS_ENDELLIPSIS") > 0 then ret = ret || " ENDELLIPSIS"
       if style~wordpos("SS_NOPREFIX") > 0 then ret = ret || " NOPREFIX"
       if style~wordpos("SS_NOTIFY") > 0 then ret = ret || " NOTIFY"
       if style~wordpos("SS_PATHELLIPSIS") > 0 then ret = ret || " PATHELLIPSIS"
       if style~wordpos("SS_RIGHTJUST") > 0 then ret = ret || " RIGHTJUST"
       if style~wordpos("SS_REALSIZECONTROL") > 0 then ret = ret || " SIZECONTROL"
       if style~wordpos("SS_REALSIZEIMAGE") > 0 then ret = ret || " SIZEIMAGE"
       if style~wordpos("SS_SUNKEN") > 0 then ret = ret || " SUNKEN"
       if style~wordpos("SS_WORDELLIPSIS") > 0 then ret = ret || " WORDELLIPSIS"

       if style~wordpos("WS_BORDER") > 0 then ret = ret || " BORDER"
       if style~wordpos("WS_TABSTOP") > 0 then ret = ret || " TAB"
   end
   else if kind = "SB" then do
      if style~wordpos("SBS_HORZ") > 0 then ret = ret || " HORIZONTAL"
      if style~wordpos("SBS_TOPALIGN") > 0 then ret = ret || " TOPLEFT"
      if style~wordpos("SBS_BOTTOMALIGN") > 0 then ret = ret || " BOTTOMRIGHT"
      if style~wordpos("WS_TABSTOP") > 0 then ret = ret || " TAB"
      if style~wordpos("WS_BORDER") > 0 then ret = ret || " BORDER"
   end

   if kind = "EDIT" | kind = "LB" | kind = "CB" then
      if style~wordpos("NOT WS_BORDER") > 0 then ret = ret || " NOBORDER"
   if kind = "EDIT" | kind = "CB" | kind = "LB" | kind = "DLG" then do
      if style~wordpos("WS_VSCROLL") > 0 then ret = ret || " VSCROLL"
      if style~wordpos("WS_HSCROLL") > 0 then ret = ret || " HSCROLL"
   end

   return ret

-- Gets the Common Control style string
::method getCcCtrlStyle private
   use arg style
   ret = ''

   if style~wordpos("CCS_ADJUSTABLE") > 0 then ret = ret || " CCS_ADJUSTABLE"
   if style~wordpos("CCS_BOTTOM") > 0 then ret = ret || " CCS_BOTTOM"
   if style~wordpos("CCS_LEFT") > 0 then ret = ret || " CCS_LEFT"
   if style~wordpos("CCS_NODIVIDER") > 0 then ret = ret || " CCS_NODIVIDER"
   if style~wordpos("CCS_NOMOVEX") > 0 then ret = ret || " CCS_NOMOVEX"
   if style~wordpos("CCS_NOMOVEY") > 0 then ret = ret || " CCS_NOMOVEY"
   if style~wordpos("CCS_NOPARENTALIGN") > 0 then ret = ret || " CCS_NOPARENTALIGN"
   if style~wordpos("CCS_NORESIZE") > 0 then ret = ret || " CCS_NORESIZE"
   if style~wordpos("CCS_RIGHT") > 0 then ret = ret || " CCS_RIGHT"
   if style~wordpos("CCS_TOP") > 0 then ret = ret || " CCS_TOP"
   if style~wordpos("CCS_VERT") > 0 then ret = ret || " CCS_VERT"

   return ret

::method getNamedCtrlStyle private
   use arg style, kind
   ret = ""
   if style~wordpos("NOT WS_VISIBLE") > 0 then ret = "HIDDEN"
   else if style~wordpos("WS_VISIBLE") > 0 then ret = "VISIBLE"
   if style~wordpos("WS_DISABLED") > 0 & style~wordpos("NOT WS_DISABLED") == 0 then ret = ret || " DISABLED"

   if kind = "DTP" then do
        if style~wordpos("DTS_APPCANPARSE") > 0 then ret = ret || " CANPARSE"
        if style~wordpos("DTS_RIGHTALIGN") > 0 then ret = ret || " RIGHT"
        if style~wordpos("DTS_SHOWNONE") > 0 then ret = ret || " SHOWNONE"
        if style~wordpos("DTS_UPDOWN") > 0 then ret = ret || " UPDOWN"
        if style~wordpos("DTS_LONGDATEFORMAT") > 0 then ret = ret || " LONG"
        if style~wordpos("DTS_SHORTDATEFORMAT") > 0 then ret = ret || " SHORT"
        if style~wordpos("DTS_SHORTDATECENTURYFORMAT") > 0 then ret = ret || " CENTURY"
        if style~wordpos("DTS_TIMEFORMAT") > 0 then ret = ret || " TIME"
        if style~wordpos("WS_BORDER") > 0 then ret = ret || " BORDER"
   end
   else if kind = "LIST" then do
      if style~wordpos("LVS_EDITLABELS") > 0 then ret = ret || " EDIT"
      if style~wordpos("LVS_SHOWSELALWAYS") > 0 then ret = ret || " SHOWSELALWAYS"
      if style~wordpos("LVS_ALIGNLEFT") > 0 then ret = ret || " ALIGNLEFT"
      if style~wordpos("LVS_ALIGNTOP") > 0 then ret = ret || " ALIGNTOP"
      if style~wordpos("LVS_AUTOARRANGE") > 0 then ret = ret || " AUTOARRANGE"
      if style~wordpos("LVS_ICON") > 0 then ret = ret || " ICON"
      if style~wordpos("LVS_SMALLICON") > 0 then ret = ret || " SMALLICON"
      if style~wordpos("LVS_LIST") > 0 then ret = ret || " LIST"
      if style~wordpos("LVS_REPORT") > 0 then ret = ret || " REPORT"
      if style~wordpos("LVS_NOCOLUMNHEADER") > 0 then ret = ret || " NOHEADER"
      if style~wordpos("LVS_NOLABELWRAP") > 0 then ret = ret || " NOWRAP"
      if style~wordpos("LVS_NOSCROLL") > 0 then ret = ret || " NOSCROLL"
      if style~wordpos("LVS_NOSORTHEADER") > 0 then ret = ret || " NOSORTHEADER"
      if style~wordpos("LVS_SHAREIMAGELISTS") > 0 then ret = ret || " SHAREIMAGES"
      if style~wordpos("LVS_SINGLESEL") > 0 then ret = ret || " SINGLESEL"
      if style~wordpos("LVS_SORTASCENDING") > 0 then ret = ret || " ASCENDING"
      if style~wordpos("LVS_SORTDESCENDING") > 0 then ret = ret || " DESCENDING"
      if style~wordpos("WS_BORDER") = 0 then ret = ret || " NOBORDER"
   end
   else if kind = "MONTH" then do
        if style~wordpos("MCS_DAYSTATE")  > 0 then ret = ret || " DAYSTATE"
        if style~wordpos("MCS_MULTISELECT")  > 0 then ret = ret || " MULTI"
        if style~wordpos("MCS_NOTODAY")  > 0 then ret = ret || " NOTODAY"
        if style~wordpos("MCS_NOTODAYCIRCLE")  > 0 then ret = ret || " NOCIRCLE"
        if style~wordpos("MCS_WEEKNUMBERS")  > 0 then ret = ret || " WEEKNUMBERS"
        if style~wordpos("WS_BORDER")  > 0 then ret = ret || " BORDER"
   end
   else if kind = "PROGRESS" then do
        if style~wordpos("PBS_VERTICAL") > 0 then ret = ret || " VERTICAL"
        if style~wordpos("PBS_SMOOTH") > 0 then ret = ret || " SMOOTH"
        if style~wordpos("PBS_MARQUEE") > 0 then ret = ret || " MARQUEE"
        if style~wordpos("WS_BORDER") > 0 then ret = ret || " BORDER"
        if style~wordpos("WS_TABSTOP") > 0 then ret = ret || " TAB"
   end
   else if kind = "REBAR" then do
       ret = ret || self~getCcStyle(style)
       if style~wordpos("RBS_AUTOSIZE") > 0 then ret = ret || " AUTOSIZE"
       if style~wordpos("RBS_BANDBORDERS") > 0 then ret = ret || " BANDBORDERS"
       if style~wordpos("RBS_DBLCLKTOGGLE") > 0 then ret = ret || " DBLCLKTOGGLE"
       if style~wordpos("RBS_FIXEDORDER") > 0 then ret = ret || " FIXEDORDER"
       if style~wordpos("RBS_REGISTERDROP") > 0 then ret = ret || " REGISTERDROP"
       if style~wordpos("RBS_TOOLTIPS") > 0 then ret = ret || " TOOLTIPS"
       if style~wordpos("RBS_VARHEIGHT") > 0 then ret = ret || " VARHEIGHT"
       if style~wordpos("RBS_VERTICALGRIPPER") > 0 then ret = ret || " VERTICALGRIPPER"
       if style~wordpos("WS_BORDER") > 0 then ret = ret || " BORDER"
   end
   else if kind = "SLIDER" then do
       if style~wordpos("TBS_AUTOTICKS") > 0 then ret = ret || " AUTOTICKS"
       if style~wordpos("TBS_NOTICKS") > 0 then ret = ret || " NOTICKS"
       if style~wordpos("TBS_VERT") > 0 then ret = ret || " VERTICAL"
       if style~wordpos("TBS_HORZ") > 0 then ret = ret || " HORIZONTAL"
       if style~wordpos("TBS_TOP") > 0 then ret = ret || " TOP"
       if style~wordpos("TBS_BOTTOM") > 0 then ret = ret || " BOTTOM"
       if style~wordpos("TBS_LEFT") > 0 then ret = ret || " LEFT"
       if style~wordpos("TBS_RIGHT") > 0 then ret = ret || " RIGHT"
       if style~wordpos("TBS_BOTH") > 0 then ret = ret || " BOTH"
       if style~wordpos("TBS_ENABLESELRANGE") > 0 then ret = ret || " ENABLESELRANGE"
       if style~wordpos("WS_BORDER") > 0 then ret = ret || " BORDER"
   end
   else if kind = "STATUS" then do
       ret = ret || self~getCcStyle(style)
       if style~wordpos("SBARS_SIZEGRIP") > 0 then ret = ret || " SIZEGRIP"
       if style~wordpos("SBARS_TOOLTIPS") > 0 then ret = ret || " TOOLTIPS"
       if style~wordpos("SBT_TOOLTIPS") > 0 then ret = ret || " TOOLTIPS"
       if style~wordpos("WS_BORDER") > 0 then ret = ret || " BORDER"
   end
   else if kind = "TAB" then do
        if style~wordpos("WS_GROUP") > 0 then ret = ret || " GROUP"
        if style~wordpos("TCS_BUTTONS") > 0 then ret = ret || " BUTTONS"
        if style~wordpos("TCS_FIXEDWIDTH") > 0 then ret = ret || " FIXED"
        if style~wordpos("TCS_FOCUSNEVER") > 0 then ret = ret || " FOCUSNEVER"
        if style~wordpos("TCS_FOCUSONBUTTONDOWN") > 0 then ret = ret || " FOCUSONDOWN"
        if style~wordpos("TCS_FORCEICONLEFT") > 0 then ret = ret || " ICONLEFT"
        if style~wordpos("TCS_FORCELABELLEFT") > 0 then ret = ret || " LABELLEFT"
        if style~wordpos("TCS_MULTILINE") > 0 then ret = ret || " MULTILINE"
        if style~wordpos("TCS_RIGHTJUSTIFY") > 0 then ret = ret || " ALIGNRIGHT"
        if style~wordpos("WS_BORDER") > 0 then ret = ret || " BORDER"
   end
   else if kind = "TOOLBAR" then do
       ret = ret || self~getCcStyle(style)
       if style~wordpos("TBSTYLE_TOOLTIPS") > 0 then ret = ret || " TOOLTIPS"
       if style~wordpos("TBSTYLE_WRAPABLE") > 0 then ret = ret || " WRAPABLE"
       if style~wordpos("TBSTYLE_ALTDRAG") > 0 then ret = ret || " ALTDRAG"
       if style~wordpos("TBSTYLE_FLAT") > 0 then ret = ret || " FLAT"
       if style~wordpos("TBSTYLE_LIST") > 0 then ret = ret || " LIST"
       if style~wordpos("TBSTYLE_CUSTOMERASE") > 0 then ret = ret || " CUSTOMERASE"
       if style~wordpos("TBSTYLE_REGISTERDROP") > 0 then ret = ret || " REGISTERDROP"
       if style~wordpos("TBSTYLE_TRANSPARENT") > 0 then ret = ret || " TRANSPARENT"
       if style~wordpos("WS_BORDER") > 0 then ret = ret || " BORDER"
   end
   else if kind = "TREE" then do
      if style~wordpos("TVS_CHECKBOXES") > 0 then ret = ret || " CHECKBOXES"
      if style~wordpos("TVS_DISABLEDRAGDROP") > 0 then ret = ret || " NODRAG"
      if style~wordpos("TVS_EDITLABELS") > 0 then ret = ret || " EDIT"
      if style~wordpos("TVS_FULLROWSELECT") > 0 then ret = ret || " FULLROWSELECT"
      if style~wordpos("TVS_HASBUTTONS") > 0 then ret = ret || " BUTTONS"
      if style~wordpos("TVS_HASLINES") > 0 then ret = ret || " LINES"
      if style~wordpos("TVS_INFOTIP") > 0 then ret = ret || " INFOTIP"
      if style~wordpos("TVS_LINESATROOT") > 0 then ret = ret || " ATROOT"
      if style~wordpos("TVS_NOHSCROLL") > 0 then ret = ret || " NOHSCROLL"
      if style~wordpos("TVS_NONEVENHEIGHT") > 0 then ret = ret || " NONEVENHEIGHT"
      if style~wordpos("TVS_NOSCROLL") > 0 then ret = ret || " NOSCROLL"
      if style~wordpos("TVS_NOTOOLTIPS") > 0 then ret = ret || " NOTOOLTIPS"
      if style~wordpos("TVS_RTLREADING") > 0 then ret = ret || " RTLREADING"
      if style~wordpos("TVS_SHOWSELALWAYS") > 0 then ret = ret || " SHOWSELALWAYS"
      if style~wordpos("TVS_SINGLEEXPAND") > 0 then ret = ret || " SINGLEEXPAND"
      if style~wordpos("TVS_TRACKSELECT") > 0 then ret = ret || " TRACKSELECT"
      if style~wordpos("WS_HSCROLL") > 0 then ret = ret || " HSCROLL"
      if style~wordpos("WS_VSCROLL") > 0 then ret = ret || " VSCROLL"
      if style~wordpos("WS_BORDER") = 0 then ret = ret || " NOBORDER"
   end
   else if kind = "UPDOWN" then do
        if style~wordpos("UDS_ALIGNLEFT")  > 0 then ret = ret || " LEFT"
        if style~wordpos("UDS_ALIGNRIGHT")  > 0 then ret = ret || " RIGHT"
        if style~wordpos("UDS_ARROWKEYS")  > 0 then ret = ret || " ARROWKEYS"
        if style~wordpos("UDS_AUTOBUDDY")  > 0 then ret = ret || " AUTOBUDDY"
        if style~wordpos("UDS_HORZ")  > 0 then ret = ret || " HORIZONTAL"
        if style~wordpos("UDS_HOTTRACK")  > 0 then ret = ret || " HOTTRACK"
        if style~wordpos("UDS_NOTHOUSANDS")  > 0 then ret = ret || " NOTHOUSANDS"
        if style~wordpos("UDS_SETBUDDYINT")  > 0 then ret = ret || " BUDDYINT"
        if style~wordpos("UDS_WRAP")  > 0 then ret = ret || " WRAP"
   end
   if style~wordpos("WS_VSCROLL") > 0 then ret = ret || " VSCROLL"
   if style~wordpos("WS_HSCROLL") > 0 then ret = ret || " HSCROLL"
   if style~wordpos("WS_TABSTOP") = 0 then ret = ret || " NOTAB"
   return ret


-- DEPRECATED (to end of file.)
::method addStatic external "LIBRARY oodialog dyndlg_createStatic"
::method addImage external "LIBRARY oodialog dyndlg_createStaticImage"
::method addButton external "LIBRARY oodialog dyndlg_addButton"
::method addRadioButton external "LIBRARY oodialog dyndlg_addRadioButton"
::method addCheckBox external "LIBRARY oodialog dyndlg_addRadioButton"
::method addGroupBox external "LIBRARY oodialog dyndlg_addGroupBox"
::method addScrollBar external "LIBRARY oodialog dyndlg_createScrollBar"
::method addEntryLine external "LIBRARY oodialog dyndlg_addEntryLine"
::method addPasswordLine external "LIBRARY oodialog dyndlg_addEntryLine"
::method addListBox external "LIBRARY oodialog dyndlg_addMethod"
::method addComboBox external "LIBRARY oodialog dyndlg_addMethod"
::method addTreeControl external "LIBRARY oodialog dyndlg_addMethod"
::method addListControl external "LIBRARY oodialog dyndlg_addMethod"
::method addProgressBar external "LIBRARY oodialog dyndlg_createProgressBar"
::method addSliderControl external "LIBRARY oodialog dyndlg_addMethod"
::method addTabControl external "LIBRARY oodialog dyndlg_addMethod"

::method addBitmapButton
   use strict arg id, x, y, cx = 0, cy = 0, text = "", msgToRaise = "", bmp, focus = "", sel = "", disabl = "", opts = ""
   return self~createBitmapButton(id, x, y, cx, cy, opts, text, msgToRaise, bmp, focus, sel, disabl)

::method addText
   use strict arg x, y, cx = 0, cy = 0, text = "", opts = "", id = (-1)
   return self~createStaticText(id, x, y, cx, cy, opts, text)

::method addWhiteRect
   use strict arg x, y, cx, cy, opts = "", id = (-1)
   return self~createWhiteRect(id, x, y, cx, cy, opts)

::method addGrayRect
   use strict arg x, y, cx, cy, opts = "", id = (-1)
   return self~createGrayRect(id, x, y, cx, cy, opts)

::method addBlackRect
   use strict arg x, y, cx, cy, opts = "", id = (-1)
   return self~createBlackRect(id, x, y, cx, cy, opts)

::method addWhiteFrame
   use strict arg x, y, cx, cy, opts = "", id = (-1)
   return self~createWhiteFrame(id, x, y, cx, cy, opts)

::method addGrayFrame
   use strict arg x, y, cx, cy, opts = "", id = (-1)
   return self~createGrayFrame(id, x, y, cx, cy, opts)

::method addBlackFrame
   use strict arg x, y, cx, cy, opts = "", id = (-1)
   return self~createBlackFrame(id, x, y, cx, cy, opts)

::method addEtchedFrame
   use strict arg x, y, cx, cy, opts = "", id = (-1)
   return self~createEtchedFrame(id, x, y, cx, cy, opts)

::method addEtchedHorizontal
   use strict arg x, y, cx, cy, opts = "", id = (-1)
   return self~createEtchedHorizontal(id, x, y, cx, cy, opts)

::method addEtchedVertical
   use strict arg x, y, cx, cy, opts = "", id = (-1)
   return self~createEtchedVertical(id, x, y, cx, cy, opts)

::method addCheckGroup
   forward message "CREATECHECKBOXGROUP"
::method addCheckBoxStem
   forward message "CREATECHECKBOXSTEM"
::method addRadioGroup
   forward message "CREATERADIOBUTTONGROUP"
::method addRadioStem
   forward message "CREATERADIOBUTTONSTEM"
::method addButtonGroup
  forward message "CREATEPUSHBUTTONGROUP"
::method addOkCancelRightBottom
   forward message 'CREATEOKCANCELRIGHTBOTTOM'
::method addOkCancelLeftBottom
   forward message 'CREATEOKCANCELLEFTBOTTOM'
::method addOkCancelRightTop
   forward message 'CREATEOKCANCELRIGHTTOP'
::method addOkCancelLeftTop
   forward message 'CREATEOKCANCELLEFTTOP'

::method addInput
   use strict arg id, attributeName = "", x, y, cx1 = 0, cx2, cy = 0, text, opts = "", idstat = (self~STATIC_ID)
   if attributeName == "" then attributeName = text
   return self~createEditInput(id, x, y, cx1, cx2, cy, text, opts, idstat, attributeName)

::method addInputGroup
   forward message "CREATEEDITINPUTGROUP"
::method addInputStem
   forward message "CREATEEDITINPUTSTEM"

::method addComboInput
   use strict arg id, attributeName = "", x, y, cx1 = 0, cx2, clines = 5, text, opts = "", idstat = (self~STATIC_ID)
   return self~createComboBoxInput(id, x, y, cx1, cx2, clines, text, opts, idstat, attributeName)

::method addIcon
   forward message "ADDICONRESOURCE"

/**
 * Windows Dialog Interface for Open Object Rexx (ooRexx.)
 *
 * The EventNotification class has methods to facilitate the mapping of events
 * in the Windows dialog to methods in the Rexx dialog object.
 */
::class 'EventNotification' mixinclass Object public

::method init_eventNotification private external "LIBRARY oodialog en_init_eventNotification"

::method addUserMsg unguarded external "LIBRARY oodialog en_addUserMessage"
::method connectActivate external "LIBRARY oodialog en_connectWmEvent"        -- WM_ACTIVATE
::method connectAllSBEvents external "LIBRARY oodialog en_connectAllSBEvents"
::method connectButtonEvent external "LIBRARY oodialog en_connectButtonEvent"
::method connectComboBoxEvent external "LIBRARY oodialog en_connectComboBoxEvent"
::method connectCommandEvents external "LIBRARY oodialog en_connectCommandEvents"
::method connectDateTimePickerEvent external "LIBRARY oodialog en_connectDateTimePickerEvent"
::method connectDraw external "LIBRARY oodialog en_connectDraw"               -- WM_DRAWITEM
::method connectEachSBEvent external "LIBRARY oodialog en_connectEachSBEvent"
::method connectEditEvent external "LIBRARY oodialog en_connectEditEvent"
::method connectFKeyPress unguarded external "LIBRARY oodialog en_connectFKeyPress"
::method connectHelp external "LIBRARY oodialog en_connectWmEvent"            -- WM_HELP (F1)
::method connectKeyPress unguarded external "LIBRARY oodialog en_connectKeyPress"
::method connectListBoxEvent external "LIBRARY oodialog en_connectListBoxEvent"
::method connectListViewEvent external "LIBRARY oodialog en_connectListViewEvent"
::method connectMonthCalendarEvent external "LIBRARY oodialog en_connectMonthCalendarEvent"
::method connectMove external "LIBRARY oodialog en_connectWmEvent"            -- WM_MOVE
::method connectNotifyEvent external "LIBRARY oodialog en_connectNotifyEvent"
::method connectPosChanged external "LIBRARY oodialog en_connectWmEvent"      -- WM_WINDOWPOSCHANGED
::method connectReBarEvent external "LIBRARY oodialog en_connectReBarEvent"
::method connectResize external "LIBRARY oodialog en_connectWmEvent"          -- WM_SIZE
::method connectResizing external "LIBRARY oodialog en_connectWmEvent"        -- WM_SIZING
::method connectScrollBarEvent external "LIBRARY oodialog en_connectScrollBarEvent"
::method connectSizeMoveEnded external "LIBRARY oodialog en_connectWmEvent"   -- WM_EXITSIZEMOVE
::method connectStaticEvent external "LIBRARY oodialog en_connectStaticEvent"
::method connectStatusBarEvent external "LIBRARY oodialog en_connectStatusBarEvent"
::method connectTabEvent external "LIBRARY oodialog en_connectTabEvent"
::method connectToolBarEvent external "LIBRARY oodialog en_connectToolBarEvent"
::method connectToolTipEvent external "LIBRARY oodialog en_connectToolTipEvent"
::method connectTrackBarEvent external "LIBRARY oodialog en_connectTrackBarEvent"
::method connectTreeViewEvent external "LIBRARY oodialog en_connectTreeViewEvent"
::method connectUpDownEvent external "LIBRARY oodialog en_connectUpDownEvent"
::method disconnectKeyPress unguarded external "LIBRARY oodialog en_disconnectKeyPress"
::method hasKeyPressConnection unguarded external "LIBRARY oodialog en_hasKeyPressConnection"

::method defListDragHandler unguarded
   use arg id, item, pt, isLMB, lc

   hc = lc~cursor_Cross   /* change cursor and store current */
   parse value lc~getRect with left top right bottom
   parse var pt oldx oldy
   origin = lc~itemPos(item)
   lmb = self~isMouseButtonDown("LEFT")
   rmb = self~isMouseButtonDown("RIGHT")
   do while (lmb \= 0 | rmb \= 0) & \(lmb \= 0 & rmb \= 0)
     pos = self~cursorPos
     parse var pos x y
     parse value lc~screenToClient(x, y) with newx newy
     hs = lc~hScrollPos; vs = lc~VScrollPos
     sx = x-right
     sy = y-bottom
      in_rx = (sx <= 30) & (newx >= -30)
      in_ry = (sy <= 30) & (newy >= -30)
      if (in_rx & in_ry) then do    /* is the mouse cursor inside the drag rectangle */
          if x<left then sx = newx - 10; else if x>right then sx = sx + 30; else sx = 0
          if y<top then sy = newy - 10; else if y>bottom then sy = sy + 30; else sy = 0
          newx = newx+hs;  newy = newy +vs;
          if newx < 0 then newx = 0
          if newy < 0 then newy = 0
          if (in_rx & oldx \= newx) | (in_ry & oldy \= newy) then do
           lc~setItemPos(item, newx, newy)
             oldx = newx
             oldy = newy
             if sx \= 0 | sy \= 0 then do
                lc~scroll(sx, sy)
                call msSleep 30
             end
        end
      end
      else do    /* no, so force the mouse cursor back inside the rectangle */
         if newx < -30 then newx = -30
         if sx > 30 then newx = (right-left) + 28
         if newy < -30 then newy = -30
         if sy > 30 then newy = (bottom-top) + 28
         parse value lc~clientToSCreen(newx, newy) with x y
         self~setCursorPos(x, y)
      end
      lmb = self~isMouseButtonDown("LEFT")
      rmb = self~isMouseButtonDown("RIGHT")
   end
   if (lmb \= 0 & rmb \= 0) then do  /* if both buttons pressed restore origin. pos */
      parse var origin x y
      lc~setItemPos(item, x, y)
   end
   lc~restoreCursorShape(hc)  /* restore old cursor */
   pos = self~cursorPos
   parse var pos x y
   self~setCursorPos(x+1, y+1)  /* move cursor to force redraw */
   return 0


::method defTreeDragHandler unguarded
   use arg id, item, pt
   reply 0
   tc = self~newTreeView(id)
   hc = tc~Cursor_Cross   /* change cursor and store current */
   parse value tc~GetRect with left top right bottom
   oldItem = 0
   nocurs = 0
   lmb = self~IsMouseButtonDown("LEFT")
   rmb = self~IsMouseButtonDown("RIGHT")
   call time "R"
   do while (lmb \= 0 | rmb \= 0) & \(lmb \= 0 & rmb \= 0)
     pos = self~CursorPos
     parse var pos x y
     parse value tc~ScreenToClient(x, y) with newx newy
      ht = tc~HitTest(newx, newy)
      if ht \= 0 & ht~wordpos("ONITEM") > 0 then do
          parse var ht newParent where
          /* check if droptarget is the current parent or one of the dragged item's children */
          if newParent \= Item & newParent \= tc~Parent(Item) & tc~IsAncestor(Item, newParent) = 0 then do
             is. = tc~ItemInfo(newParent)
             if is.!State~Wordpos("INDROP") = 0 then
             do
                 call time "R"
                 tc~DropHighlight(newParent)
                 if nocurs \= 0 then do
                    tc~RestoreCursorShape(nocurs)  /* restore old cursor (cross) */
                    nocurs = 0
                 end
             end
             else if time("E") > 1 then do  /* expand node after 1 second */
                 if is.!Children \= 0 & is.!State~Wordpos("EXPANDED") = 0 then tc~expand(newParent)
             end
          end
          else do
             if nocurs = 0 then do
                nocurs = tc~Cursor_No  /* set no cursor and retrieve current cursor (cross) */
                tc~DropHighlight(newParent)  /* remove drop highlight */
             end
          end
      end
      else do
          if newParent \= 0 then do
              /* necessary to redraw cursor when moving on a valid item again */
              tc~DropHighlight(newParent)  /* remove drop highlight */
              newParent = 0
          end

          if nocurs = 0 then nocurs = tc~Cursor_No  /* set no cursor and retrieve current cursor (cross) */
          /* handle scrolling */
          fvItem = tc~FirstVisible
          if (y<top) & (fvItem \= tc~Root) then do
              tc~MakeFirstVisible(tc~PreviousVisible(fvItem))
              if top-y < 200 then call msSleep 200-(top-y)
          end
          else if (y>bottom) & (tc~NextVisible(fvItem) \= 0) then do
              tc~MakeFirstVisible(tc~NextVisible(fvItem))
              if y-bottom < 200 then call msSleep 200-(y-bottom)
          end

      end
      lmb = self~IsMouseButtonDown("LEFT")
      rmb = self~IsMouseButtonDown("RIGHT")
   end
   if ht~wordpos("ONITEM") > 0 & lmb = 0 & rmb = 0 then do /* if mouse on item and both mouse buttons up */
       item = tc~MoveItem(Item, newParent, 1)  /* move item under newParent */
   end
   tc~DropHighlight(0)  /* remove drop highlight */
   tc~select(item)      /* select item */
   tc~EnsureVisible(item)
   tc~RestoreCursorShape(hc)  /* restore old cursor */
   pos = self~CursorPos
   parse var pos x y
   self~SetCursorPos(x+1, y+1)  /* move cursor to force redraw */
   return -- cannot return a value after a REPLY


-- DEPRECATED (all methods to end of file.)
::method connectControl
   forward message "CONNECTCOMMANDEVENTS"
::method connectCommonNotify
   forward message "CONNECTNOTIFYEVENT"
::method connectTreeNotify
   forward message "CONNECTTREEVIEWEVENT"
::method connectListNotify
   forward message "CONNECTLISTVIEWEVENT"
::method connectListViewNotify
   forward message "CONNECTLISTVIEWEVENT"
::method connectButtonNotify
   forward message"CONNECTBUTTONEVENT"
::method connectEditNotify
   forward message "CONNECTEDITEVENT"
::method connectListBoxNotify
   forward message "CONNECTLISTBOXEVENT"
::method connectComboBoxNotify
   forward message "CONNECTCOMBOBOXEVENT"
::method connectScrollBarNotify
   forward message "CONNECTSCROLLBAREVENT"
::method connectTabNotify
   forward message "CONNECTTABEVENT"
::method connectSliderNotify
   forward message "CONNECTTRACKBAREVENT"
::method connectStaticNotify
   forward message "CONNECTSTATICEVENT"
::method connectScrollBar
   forward message "CONNECTEACHSBEVENT"

::method connectMenuItem
   use strict arg id, msgToRaise
   return .Menu~connectCommandEvent(id, msgToRaise, self)

::method connectButton
   use strict arg id, msgToRaise
   return self~connectButtonEvent(id, "CLICKED", msgToRaise)

::method connectList
   use strict arg id, msgToRaise
   return self~connectListBoxEvent(id, "SELCHANGE", msgToRaise)

::method connectListLeftDoubleClick
   use strict arg id, msgToRise
   return self~connectListBoxEvent(id, "DBLCLK", msgToRaise)

-- WM_CAPTURECHANGED
::method connectMouseCapture
   use strict arg methodName = 'onCaptureChanged'
   mouse = .Mouse~new(self)
   return (mouse~connectEvent('CAPTURECHANGED', methodName, .false) \== .true)


/**
 * Windows Dialog Interface for Open Object Rexx (ooRexx.)
 *
 * The basic dialog class
 *
 * PlainBaseDialog with its two inherited mixin classes, WindowBase and
 * ResourceUtils, is the base dialog for all dialogs in the ooDialog framwork.
 */

/* The WindowBase class implements methods that are common to all windows.  The
 * methods only require the operating system window handle to function.
 */
::class 'WindowBase' public mixinclass object

::method init_windowBase private external "LIBRARY oodialog wb_init_windowBase"

::attribute initCode get external "LIBRARY oodialog wb_getInitCode"
::attribute initCode set external "LIBRARY oodialog wb_setInitCode"

::attribute hwnd get external "LIBRARY oodialog wb_getHwnd"

-- Size and Dialog Unit Factor
::attribute sizeX get external "LIBRARY oodialog wb_getSizeX"
::attribute sizeX set external "LIBRARY oodialog wb_setSizeX"

::attribute sizeY get external "LIBRARY oodialog wb_getSizeY"
::attribute sizeY set external "LIBRARY oodialog wb_setSizeY"

::attribute factorX get external "LIBRARY oodialog wb_getFactorX"
::attribute factorX set external "LIBRARY oodialog wb_setFactorX"

::attribute factorY get external "LIBRARY oodialog wb_getFactorY"
::attribute factorY set external "LIBRARY oodialog wb_setFactorY"

-- True size in pixels
::attribute pixelCX get external "LIBRARY oodialog wb_getPixelCX"
::attribute pixelCY get external "LIBRARY oodialog wb_getPixelCY"

::method childWindowFromPoint unguarded external "LIBRARY oodialog wb_childWindowFromPoint"
::method clear unguarded external "LIBRARY oodialog wb_clear"
::method client2screen unguarded external "LIBRARY oodialog wb_screenClient"
::method clientRect unguarded external "LIBRARY oodialog wb_clientRect"
::method disable unguarded external "LIBRARY oodialog wb_enable"
::method display unguarded external "LIBRARY oodialog wb_display"
::method draw unguarded external "LIBRARY oodialog wb_redrawClient"
::method enable unguarded external "LIBRARY oodialog wb_enable"
::method foregroundWindow unguarded external "LIBRARY oodialog wb_foreGroundWindow"
::method hide unguarded external "LIBRARY oodialog wb_show"
::method getExStyleRaw unguarded
  return self~getWindowLong(-20)

::method getID unguarded
  return self~getWindowLong(-12)

::method getRealPos unguarded external "LIBRARY oodialog wb_getSizePos"
::method getRealSize unguarded external "LIBRARY oodialog wb_getSizePos"
::method getStyleRaw unguarded
  return self~getWindowLong(-16)

::method getText unguarded external "LIBRARY oodialog wb_getText"
::method getTextSizePx unguarded external "LIBRARY oodialog wb_getTextSizePx"
::method getTextSizeScreen unguarded external "LIBRARY oodialog wb_getTextSizeScreen"
::method hideFast unguarded external "LIBRARY oodialog wb_showFast"
::method isEnabled unguarded external "LIBRARY oodialog wb_isEnabled"
::method isVisible unguarded external "LIBRARY oodialog wb_isVisible"
::method mapWindowPoints unguarded external "LIBRARY oodialog wb_mapWindowPoints"
::method moveTo unguarded external "LIBRARY oodialog wb_resizeMove"
::method moveWindow unguarded external "LIBRARY oodialog wb_moveSizeWindow"
::method redraw unguarded external "LIBRARY oodialog wb_redraw"
::method redrawClient unguarded external "LIBRARY oodialog wb_redrawClient"
::method resizeTo unguarded external "LIBRARY oodialog wb_resizeMove"
::method screen2client unguarded external "LIBRARY oodialog wb_screenClient"
::method sendMessage unguarded external "LIBRARY oodialog wb_sendMessage"
::method sendMessageHandle unguarded external "LIBRARY oodialog wb_sendMessage"
::method setRect unguarded external "LIBRARY oodialog wb_setRect"
::method setStyleRaw unguarded
  use strict arg newValue
  return self~setWindowLong(-16, newValue)

::method setText unguarded external "LIBRARY oodialog wb_setText"
::method setTitle unguarded external "LIBRARY oodialog wb_setText"
::method setWindowPos unguarded external "LIBRARY oodialog wb_setWindowPos"
::method show unguarded external "LIBRARY oodialog wb_show"
::method showFast unguarded external "LIBRARY oodialog wb_showFast"
::method sizeWindow unguarded external "LIBRARY oodialog wb_moveSizeWindow"
::method title unguarded external "LIBRARY oodialog wb_getText"
::method "title=" unguarded external "LIBRARY oodialog wb_setText"
::method update unguarded external "LIBRARY oodialog wb_redrawClient"
::method updateWindow unguarded external "LIBRARY oodialog wb_updateWindow"
::method windowRect unguarded external "LIBRARY oodialog wb_windowRect"


::method clientToScreen unguarded   -- old method returns coordinates as a string
    use strict arg x, y
    p = .Point~new(x, y)
    if self~client2screen(p) then return p~x p~y
    else return 0 0

::method getSize unguarded          -- old method, this is not accurate.
   forward message "getRealSize" continue
   size = result
   return (size~width % self~factorX) || " " || (size~height % self~factorY)

::method getPos unguarded           -- old method, this is not accurate.
   forward message "getRealPos" continue
   p = result
   return (p~x % self~factorX) || " " || (p~y % self~factorY)

::method getRect unguarded          -- old method returns coordinates as a string
   forward message "windowRect" continue
   rect = result
   return rect~left rect~top rect~right rect~bottom

::method getClientRect unguarded    -- old method returns coordinates as a string
   forward message "clientRect" continue
   rect = result
   return rect~left rect~top rect~right rect~bottom

::method move unguarded             -- old method, this is not accurate.
   use strict arg xPos, yPos, showOptions = ""
   p = .Point~new(trunc(xPos * self~factorX), trunc(yPos * self~factorY))
   s = .Size~new(0, 0)
   if self~setRect(p, s, "NOSIZE " || showOptions) then return 0
   else return 1

::method resize unguarded           -- old method, this is not accurate.
   use strict arg width, height, showOptions = ""
   p = .Point~new(0, 0)
   s = .Size~new(trunc(width * self~factorX), trunc(height * self~factorY))
   if self~setRect(p, s, "NOMOVE " || showOptions) then return 0
   else return 1

::method screenToClient unguarded   -- old method returns coordinates as a string
    use strict arg x, y
    p = .Point~new(x, y)
    if self~screen2client(p) then return p~x p~y
    else return 0 0

-- These shortcut methods are for internal use, do not document.
::method getWindowLong private unguarded external "LIBRARY oodialog wb_getWindowLong_pvt" -- Not intending to document getWindowLong, at this point
::method setWindowLong private unguarded external "LIBRARY oodialog wb_setWindowLong_pvt" -- Not intending to document setWindowLong, at this point
::method sendWinHandle2Msg unguarded external "LIBRARY oodialog wb_sendWinHandle2Msg"   -- Internal use do not document
::method sendWinHandle2MsgH unguarded external "LIBRARY oodialog wb_sendWinHandle2Msg"  -- Internal use do not document
::method sendWinHandleMsg unguarded external "LIBRARY oodialog wb_sendWinHandleMsg"     -- Internal use do not document
::method sendWinHandleMsgH unguarded external "LIBRARY oodialog wb_sendWinHandleMsg"    -- Internal use do not document
::method sendWinIntMsg unguarded external "LIBRARY oodialog wb_sendWinIntMsg"           -- Internal use do not document
::method sendWinIntMsgH unguarded external "LIBRARY oodialog wb_sendWinIntMsg"          -- Internal use do not document
::method sendWinUintMsg unguarded external "LIBRARY oodialog wb_sendWinUintMsg"         -- Internal use do not document

::method unknown unguarded
   use arg msgname
   call errorDialog msgname || " is not a method of " || self

::method assignWindow               -- DEPRECATED
   return 0

::method getSystemMetrics unguarded -- DEPRECATED
   use strict arg index
   return .DlgUtil~getSystemMetrics(index)


::class 'Window' public inherit WindowBase
::method init  external "LIBRARY oodialog window_init"
::method unInit  external "LIBRARY oodialog window_unInit"


/**
 * Used to return an object that is not a dialog object.  See the
 * PlainBaseDialog::new() class method for details (pbdlg_new_cls.)
 */
::class 'DialogProxy' public
::attribute initCode get
  return 1

/**
 *  The PlainBaseDialog class is the base class of all ooDialog dialogs.  It
 *  implements those methods that are common to all dialogs, whether the dialog
 *  template comes from a binary resource, a resource script file, or is con-
 *  structed dynamically.
 */
::class 'PlainBaseDialog' public inherit WindowBase ResourceUtils EventNotification DialogExtensions WindowExtensions

::constant DM_REPOSITION                 "0x0402"
::constant WM_SETFONT                    "0x0030"
::constant WM_NEXTDLGCTL                 "0x0028"
::constant WM_USER_INTERRUPTSCROLL       "0x0A02"

::constant SIZE_RESTORED                       0
::constant SIZE_MINIMIZED                      1
::constant SIZE_MAXIMIZED                      2
::constant SIZE_MAXSHOW                        3
::constant SIZE_MAXHIDE                        4

::constant IDOK                                1
::constant IDCANCEL                            2
::constant IDABORT                             3
::constant IDRETRY                             4
::constant IDIGNORE                            5
::constant IDYES                               6
::constant IDNO                                7
::constant IDCLOSE                             8
::constant IDHELP                              9
::constant IDTRYAGAIN                         10
::constant IDCONTINUE                         11
::constant IDTIMEOUT                       32000


::method init class external "LIBRARY oodialog pbdlg_init_cls"
::method setDefaultFont class external "LIBRARY oodialog pbdlg_setDefaultFont_cls"
::method getFontName class external "LIBRARY oodialog pbdlg_getFontName_cls"
::method getFontSize class external "LIBRARY oodialog pbdlg_getFontSize_cls"
::method new class external "LIBRARY oodialog pbdlg_new_cls"

-- A queue containing the methods that will be started concurrently before execution of the dialog
::attribute automaticMethods private                                                            -- Protected in 3.0.1 do not document

::attribute dataConnection private  -- store connections between ids and class attributes       -- Protected in 3.0.1 do not document
::method dlgData private                                                                        -- Internal use do not document
   expose dlgData.
   return dlgData.

::attribute library get unguarded private external "LIBRARY oodialog pbdlg_getLibrary"          -- Internal use do not document
::attribute parentDlg get private external "LIBRARY oodialog pbdlg_getParentDlg_pvt"            -- Protected in 3.0.1 do not document
::attribute parentDlg set private external "LIBRARY oodialog pbdlg_setParentDlg_pvt"            -- Protected in 3.0.1 do not document
::attribute childDialogs                                                                        -- Internal use do not document
::attribute resourceID get unguarded private external "LIBRARY oodialog pbdlg_getResourceID"    -- Internal use do not document
::attribute useStem private         -- flag whether to use a stem to set/get data or not        -- Protected in 3.0.1 do not document

-- Documented attributes:
::attribute autoDetect get external "LIBRARY oodialog pbdlg_getAutoDetect"
::attribute autoDetect set external "LIBRARY oodialog pbdlg_setAutoDetect"

::attribute dlgHandle get unguarded external "LIBRARY oodialog pbdlg_getDlgHandle"

::attribute dlgID get external "LIBRARY oodialog pbdlg_getDlgID"
::attribute dlgID set external "LIBRARY oodialog pbdlg_setDlgID"

-- finsished is now a boolean, when set to .true, the dialog ends.  Older ooDialog set it
-- to 2 on an abnormal termination of the underlying dialog.  This is no longer done.
-- finished presents a problem because it was documented, mostly *incorrectly* in earlier
-- versions of ooDialog. The programmer should *not* set this attribute.  It will no longer
-- be documented because it is really an internal use only attribute.
::attribute finished get external "LIBRARY oodialog pbdlg_getFinished"
::attribute finished set external "LIBRARY oodialog pbdlg_setFinished"

::attribute fontName get external "LIBRARY oodialog pbdlg_getFontNameSize"
::attribute fontName set private external "LIBRARY oodialog pbdlg_setFontName_pvt"
::attribute fontSize get external "LIBRARY oodialog pbdlg_getFontNameSize"
::attribute fontSize set private external "LIBRARY oodialog pbdlg_setFontSize_pvt"
::attribute ownerDialog get  external "LIBRARY oodialog pbdlg_getOwnerDialog"
::attribute ownerDialog set  external "LIBRARY oodialog pbdlg_setOwnerDialog"


/** PlainBaseDialog::init()  Performs the necessary intialization, including the
 * set up of the dialog management block, for all dialogs.
 */
::method init external "LIBRARY oodialog pbdlg_init"
::method setDlgFont external "LIBRARY oodialog pbdlg_setDlgFont"

-- Creates the dialog, shows it, and destroys it.  Dialog "data" is set and received.
-- The sleepTime arg is ignored.  This arg was never documented, but people might have
-- used it anyway, so it is left in the arg list. Do not document modeless, it is an
-- implementation detail that may be removed if true modal dialog are ever implemented
::method execute unguarded
   expose dlgData.
   use strict arg sh = "NORMAL", icon = 0, sleepTime = 1, modeless = .false

   icon = self~resolveIconId(icon)
   if self~startIt(icon, modeless) \= 0 then do
      if self~useStem then self~setDataStem(dlgData.)
      else self~setData
      self~show(sh)
      do while self~automaticMethods~Items > 0
         p = self~automaticMethods~pull
         m = self~automaticMethods~pull
         c = self~automaticMethods~pull
         o = c~new(p, self)
         o~start(m)
      end

      self~waitForDialog

      if self~initCode = 1 then do
         if self~useStem then self~getDataStem(dlgData.)
         self~getData
      end
      self~stopIt
      return self~initCode
   end
   else do
      self~finished = .true
      self~stopIt
      return 0
   end

::method isDialogActive unguarded external "LIBRARY oodialog pbdlg_isDialogActive"


 /*
  * The following methods are the default implementations for methods that are
  * intended to be over-ridden by the programmer if the default behavior needs
  * to be altered.
  */

::method initDialog unguarded
   return 0

 /** ok()
  * This method first invokes the validate() method.  If validate returns
  * true, self~initCode is set to 1 and self~finished is set to true,
  * terminating the dialog.
  *
  * If validate returns false, the dialog continues to run.
  */
::method ok unguarded
   okayToClose = self~validate

   if okayToClose then do
     self~initCode = 1
     self~finished = .true
   end

   return self~finished

::method cancel unguarded
   self~initCode = 2
   self~finished = .true
   return self~finished

::method help unguarded
   return 0

::method leaving
   return 0

/** validate()
 * This method is an abstract method that will be called to determin whether the
 * dialog can be closed or not. This function will be called by method OK.  If
 * the return value is true the dialog can be closed, if it is false the dialog
 * should not be closed.
 */
::method validate unguarded
   return .true



-- waitForDialog() replaces the run() method.  run() now just spins doing nothing.
::method waitForDialog unguarded                           -- Not to be doumented.
   expose finished
   guard on when finished

::method ensureFinished unguarded                          -- Not to be doumented.
  expose finished
  use strict arg wasAbnormalHalt
  if wasAbnormalHalt then self~initCode = 3
  finished = .true

::method stopIt external "LIBRARY oodialog pbdlg_stopIt"   -- Not to be doumented. Documented "internal use only" in 3.2.0
::method finalStopIt private                               -- Not to be doumented.
   use arg caller

   -- If we ourselves are a child dialog and not called by the parent's stopIt(), then
   -- remove ourself from the parent dialog's child list.  (Child dialogs are independent
   -- and the user could close them at any time.)
   if self~parentDlg \== .nil & caller \== "PARENT" then self~parentDlg~childDied(self)

   -- If we have child dialogs, then stop all of them.  Child dialogs are always started
   -- through popupAsChild() and are always closed when the parent closes.
   if self~childDialogs \== .nil then do
       if self~childDialogs~items > 0 then
       do child over self~childDialogs
          child~stopit("PARENT")
       end
       self~childDialogs = .nil
   end
   return 0


-- Remove a child dialog from the chain of child dialogs.
::method childDied                                         -- Not to be doumented.
   use arg child
   if self~childDialogs \== .nil then do
       ndx = self~childDialogs~first
       do while ndx \== .nil
          if self~childDialogs[ndx] == child then do
              self~childDialogs~remove(ndx)
              ndx = .nil
          end
          else ndx = self~childDialogs~next(ndx)
       end
   end

::method unInit external "LIBRARY oodialog pbdlg_unInit"   -- Not to be doumented.


::method sendMessageToWindow unguarded external "LIBRARY oodialog pbdlg_sendMessageToWindow"
::method sendMessageToWindowH unguarded external "LIBRARY oodialog pbdlg_sendMessageToWindow"
::method sendMessageToControl unguarded external "LIBRARY oodialog pbdlg_sendMessageToControl"
::method sendMessageToControlH unguarded external "LIBRARY oodialog pbdlg_sendMessageToControl"

::method get unguarded external "LIBRARY oodialog pbdlg_get"
::method getSelf unguarded external "LIBRARY oodialog pbdlg_getDlgHandle"
::method getControlID unguarded external "LIBRARY oodialog pbdlg_getControlID"
::method show unguarded external "LIBRARY oodialog pbdlg_show"
::method restore unguarded external "LIBRARY oodialog pbdlg_show"
::method toTheTop unguarded external "LIBRARY oodialog pbdlg_toTheTop"
::method minimize unguarded external "LIBRARY oodialog pbdlg_doMinMax"
::method maximize unguarded external "LIBRARY oodialog pbdlg_doMinMax"
::method isMaximized unguarded external "LIBRARY oodialog pbdlg_doMinMax"
::method isMinimized unguarded external "LIBRARY oodialog pbdlg_doMinMax"
::method getWindowText unguarded external "LIBRARY oodialog pbdlg_getWindowText"
::method setWindowText unguarded external "LIBRARY oodialog pbdlg_setWindowText"
::method getControlText unguarded external "LIBRARY oodialog pbdlg_getControlText"
::method setControlText unguarded external "LIBRARY oodialog pbdlg_setControlText"
::method getControlHandle unguarded external "LIBRARY oodialog pbdlg_getControlHandle"
::method getTextSizeDu unguarded external "LIBRARY oodialog pbdlg_getTextSizeDu"
::method getTextSizeDlg unguarded external "LIBRARY oodialog pbdlg_getTextSizeDlg"
::method getTextSizeTitleBar unguarded external "LIBRARY oodialog pbdlg_getTextSizeTitleBar"
::method pixel2dlgUnit external "LIBRARY oodialog pbdlg_pixel2dlgUnit"
::method dlgUnit2pixel external "LIBRARY oodialog pbdlg_dlgUnit2pixel"
::method backgroundBitmap external "LIBRARY oodialog pbdlg_backgroundBitmap"
::method tiledBackgroundBitmap external "LIBRARY oodialog pbdlg_tiledBackgroundBitmap"
::method backgroundColor external "LIBRARY oodialog pbdlg_backgroundColor"
::method backgroundSysColor external "LIBRARY oodialog pbdlg_backgroundColor"

::method ensureVisible unguarded
   return self~sendWinIntMsg(self~DM_REPOSITION, 0, 0)


-- initAutoDetection() is invoked by init() to set the default for automatic data field detection.
::method initAutoDetection private                                                               -- First data attribute method
   .application~initAutoDetection(self)

::method noAutoDetection
   self~autoDetect = .false      -- disable autodetection

::method autoDetection
   self~autoDetect = .true       -- enable autodetection

/* The following methods 'connect' a Windows dialog control with a 'data' attribute of the Rexx
 * dialog object.  For each dialog control an attribute of the dialog object is created and an
 * entry is added to the data table to 'connect' the control and the attribute.  When auto detection
 * is on the 'data' (which is the value of the attribute) attribute is used to set the state of the
 * control on start up of the dialog.  Likewise, when the windows dialog is closed, the 'data' (the state)
 * of the control is used to set the value of the attribute.
 */

::method connectCheckBox unguarded external "LIBRARY oodialog pbdlg_connect_ControName"
::method connectRadioButton unguarded external "LIBRARY oodialog pbdlg_connect_ControName"
::method connectEdit unguarded external "LIBRARY oodialog pbdlg_connect_ControName"
::method connectComboBox unguarded external "LIBRARY oodialog pbdlg_connect_ControName"
::method connectListBox unguarded external "LIBRARY oodialog pbdlg_connect_ControName"
::method connectTreeView unguarded external "LIBRARY oodialog pbdlg_connect_ControName"
::method connectListView unguarded external "LIBRARY oodialog pbdlg_connect_ControName"
::method connectTrackBar unguarded external "LIBRARY oodialog pbdlg_connect_ControName"
::method connectTab unguarded external "LIBRARY oodialog pbdlg_connect_ControName"
::method connectDateTimePicker unguarded external "LIBRARY oodialog pbdlg_connect_ControName"
::method connectMonthCalendar unguarded external "LIBRARY oodialog pbdlg_connect_ControName"
::method connectUpDown unguarded external "LIBRARY oodialog pbdlg_connect_ControName"

-- This method gets the 'data' of all the connected dialog controls and uses that data to set the value of the
-- associated attribute.  See comment above for setData()
::method getData unguarded
   self~putDlgDataInStem(InternDlgData.)

   id = self~dataConnection~first
   do while (id \== .nil)
      self~sendWith(self~dataConnection[id]'=', .array~of(InternDlgData.id))
      id = self~dataConnection~next(id)
   end


-- This method sets the 'data' of all the connected dialog controls using the value of the associated attribute.
-- The Windows dialog controls are associated with with a data attribute of the Rexx dialog object through the
-- connectXXX methods.  connectListBox(), connectComboBox(), etc..
::method setData unguarded
   id = self~dataConnection~first
   do while (id \== .nil)
      data = self~send(self~dataConnection[id])
      InternDlgData.id = data
      id = self~dataConnection~next(id)
   end
   return self~setDlgDataFromStem(InternDlgData.)


-- This method gets the 'data' of all of the connected dialog controls and sets the indexes of the specified
-- stem with the 'data'.  The resource ID of each dialog control is used as an index and the 'data' of that
-- dialog control is set as the value.  In addition, if the numeric resource ID has a matching symbolic ID in
-- the constDir, then the symbolic ID is used as a second index and set with the 'data' of the the dialog control.
::method getDataStem unguarded
   use arg dataStem.
   self~putDlgDataInStem(InternDlgData.)
   do k over InternDlgData.
      dataStem.k = InternDlgData.k
      symbolicID = self~resolveNumericID(k)
      if symbolicID \== -1 then dataStem.symbolicID = InternDlgData.k
   end


-- This method sets the 'data' of each of the connected dialog controls using the values of the specified stem.
-- Each index of the stem should be the resource ID of a connected dialog control and the value at that index is
-- the 'data' to set the control with.
::method setDataStem unguarded
   use arg dataStem.
   if dataStem.~items == 0 then return 1
   do k over dataStem.
      if k~dataType('W') then numericID = k
      else numericID = self~resolveSymbolicID(k)
      if numericID == -1 then iterate
      InternDlgData.numericID = dataStem.k
      if InternDlgData.numericID = "INTERNDLGDATA."numericID then InternDlgData.numericID = ""
   end
   return self~setDlgDataFromStem(InternDlgData.)


-- The following methods are used to get the 'data' from a single dialog control

-- This method gets the 'data' of a dialog control. You don't have to know what kind of control it is
-- if it has been 'connected' previously, i.e. connectTreeView(), connectTab(), etc..
::method getControlData unguarded external "LIBRARY oodialog pbdlg_getControlData"
::method getCheckBoxData unguarded external "LIBRARY oodialog pbdlg_getControlData"
::method getRadioButtonData unguarded external "LIBRARY oodialog pbdlg_getControlData"
::method getEditData unguarded external "LIBRARY oodialog pbdlg_getControlData"
::method getListBoxData unguarded external "LIBRARY oodialog pbdlg_getControlData"
::method getComboBoxData unguarded external "LIBRARY oodialog pbdlg_getControlData"

-- This method gets the 'data' of a dialog control and uses that data to set the value of the attribute
-- associated with the dialog control through one of the connectXXX methods.  I.e., connectEdit(),
-- connectListBox(), etc..  It returns nothing to the caller, the action is setting the value of the
-- associated attribute.
::method getDataAttribute unguarded
   use strict arg attributeName
   id = self~dataConnection~First
   do while (id \== .nil)
      if self~dataConnection[id] = attributeName~space(0) then do
         data = self~getControlData(id)
         self~sendWith(attributeName'=', .array~of(data))
         return
      end
      id = self~dataConnection~next(id)
   end


-- The following methods are used to set the 'data' of a single dialog item

-- This method sets the 'data' of a dialog control. You don't have to know what kind of control it is
-- if it has been 'connected' previously, i.e. connectTreeView(), connectTab(), etc..
::method setControlData unguarded external "LIBRARY oodialog pbdlg_setControlData"

::method setCheckBoxData unguarded external "LIBRARY oodialog pbdlg_setControlData"
::method setRadioButtonData unguarded external "LIBRARY oodialog pbdlg_setControlData"
::method setEditData unguarded external "LIBRARY oodialog pbdlg_setControlData"
::method setListBoxData unguarded external "LIBRARY oodialog pbdlg_setControlData"
::method setComboBoxData unguarded external "LIBRARY oodialog pbdlg_setControlData"

-- This method sets the 'data' of a dialog control using the value of the attribute associated with
-- the dialog control through one of the connectXXX methods.  I.e., connectEdit(), connectListBox()
::method setDataAttribute unguarded
   use strict arg attributeName
   id = self~dataConnection~first
   do while (id \== .nil)
      if self~dataConnection[id] = attributeName~space(0) then do
         data = self~send(attributeName)
         return self~setControlData(id, data)
      end
      id = self~dataConnection~next(id)
   end

-- Documented "internal use only" in 3.2.0 - Do not document.
::method addAttribute private                                                                           -- Not to be doumented.
   use strict arg id, attributeName = ("DATA"id~space(0))

   if \ id~dataType("W") then do
       if self~processingLoad = 1 then attributeName = id
       id = self~resolveSymbolicId(id)
   end
   if id < 1 then return -1

   -- Remove any possible spaces, &, and :, then check for a valid name
   attributeName = attributeName~space(0)~changestr('&','')~changestr(':','')
   if attributeName == "" | self~HasMethod(attributeName) | \ attributeName~datatype('V') then
       attributeName = "DATA"id~space(0)

   self~dataConnection[id] = attributeName
   self~setMethod(attributeName, "expose "attributeName"; return "attributeName)
   self~setMethod(attributeName || "=", "expose "attributeName"; use arg "attributeName)
   self~sendWith(attributeName || '=', .array~of(""))  /* initial value = "" */
   return id


-- The method returns an array that contains the value of each of the attributes associated with a dialog
-- control.  MM What good is this, you don't know which control is associated with each of the 'data' pieces?
::method makeArray unguarded  -- Never documented, do not intend to document now                 -- Last data attribute method.

   a = .array~new(self~dataConnection~items)
   id = self~dataConnection~first
   do j = 1 while (id \== .nil)
      attributeName = self~dataConnection~at(id)
      data = self~send(attributeName)
      a[j] = data
      id = self~dataConnection~next(id)
   end
   return a


-- Internal use *only*, do *not* use. - Do not document.
::method setDlgDataFromStem private unguarded external "LIBRARY oodialog pbdlg_setDlgDataFromStem_pvt"  -- Not to be doumented.
::method putDlgDataInStem private unguarded external "LIBRARY oodialog pbdlg_putDlgDataInStem_pvt"      -- Not to be doumented.
::method putControl unguarded external "LIBRARY oodialog pbdlg_putControl"                              -- Not to be doumented.


-- Allow the user to dynamically add attributes or methods to a dialog.

::method addNewAttribute
   use strict arg name, value = "", makeUnguarded = .false, makePrivate = .false

   self~setMethod(name, "expose "name"; return "name, "OBJECT")
   self~setMethod(name || "=", "expose "name"; use arg "name, "OBJECT")

   if makeUnguarded then do
      self~instanceMethod(name)~setUnguarded
      self~instanceMethod(name || '=')~setUnguarded
   end

   if makePrivate then do
      self~instanceMethod(name)~setPrivate
      self~instanceMethod(name || '=')~setPrivate
   end

   self~sendWith(name || '=', .array~of(value))

::method addNewMethod
   use strict arg name, src, makeUnguarded = .false, makePrivate = .false

   self~setMethod(name, src, "OBJECT")

   if makeUnguarded then self~instanceMethod(name)~setUnguarded
   if makePrivate then self~instanceMethod(name)~setPrivate
   return 0

-- Methods to manipulate a ComboBox

::method addComboEntry unguarded
   use strict arg id, string
   comboBox = self~newComboBox(id)
   if comboBox == .nil then return -1
   else return comboBox~add(string)

::method insertComboEntry unguarded
   use strict arg id, index = 0, string
   comboBox = self~newComboBox(id)
   if comboBox == .nil then return -1
   if arg(2, 'O') then return comboBox~insert( , string)
   else return comboBox~insert(index, string)

::method findComboEntry unguarded
   use strict arg id, string
   comboBox = self~newComboBox(id)
   if comboBox == .nil then return -1
   return comboBox~find(string)

::method getComboEntry unguarded
   use strict arg id, index
   comboBox = self~newComboBox(id)
   if comboBox == .nil then return -1
   return comboBox~getText(index)

::method comboAddDirectory unguarded
   use strict arg id, drivepath, fileAttributes = ""
   comboBox = self~newComboBox(id)
   if comboBox == .nil then return -1
   return comboBox~addDirectory(drivePath, fileAttributes)

::method deleteComboEntry unguarded
   use strict arg id, index = (self~getCurrentComboIndex(id))
   if index <= 0 then return -1
   comboBox = self~newComboBox(id)
   if comboBox == .nil then return -1
   return comboBox~delete(index)

::method getCurrentComboIndex unguarded
   use strict arg id
   comboBox = self~newComboBox(id)
   if comboBox == .nil then return -1
   return comboBox~selectedIndex

::method setCurrentComboIndex unguarded
   use strict arg id, ndx = 0
   comboBox = self~newComboBox(id)
   if comboBox == .nil then return -1
   return comboBox~selectIndex(ndx)

::method getComboItems unguarded
   use strict arg id
   comboBox = self~newComboBox(id)
   if comboBox == .nil then return -1
   return comboBox~items

::method changeComboEntry unguarded
   use strict arg id, item = (self~getCurrentComboIndex(id)), string
   if item <= 0 then return -1
   self~deleteComboEntry(id, item)
   return self~insertComboEntry(id, item, string)

::method comboDrop unguarded
   use strict arg id
   comboBox = self~newComboBox(id)
   if comboBox == .nil then return -1
   return comboBox~deleteAll

-- Methods to manipulate a ListBox

::method setListTabulators unguarded external "LIBRARY oodialog generic_setListTabulators"

::method addListEntry unguarded
   use strict arg id, text
   listBox = self~newListBox(id)
   if listBox == .nil then return -1
   else return listBox~add(text)

::method insertListEntry unguarded
   use strict arg id, index = (-2), text
   listBox = self~newListBox(id)
   if listBox == .nil then return -1
   if arg(2, 'O') then return listBox~insert( , text)
   else return listBox~insert(index, text)

::method findListEntry unguarded
   use strict arg id, text
   listBox = self~newListBox(id)
   if listBox == .nil then return -1
   return listBox~find(text)

::method getListEntry unguarded
   use strict arg id, index
   listBox = self~newListBox(id)
   if listBox == .nil then return -1
   return listBox~getText(index)

::method listAddDirectory unguarded
   use strict arg id, drivePath, fileAttributes = ""
   listBox = self~newListBox(id)
   if listBox == .nil then return -1
   return listBox~addDirectory(drivePath, fileAttributes)

::method deleteListEntry unguarded
   use strict arg id, index = (self~getCurrentListIndex(id))
   if index == 0 then return -1
   listBox = self~newListBox(id)
   if listBox == .nil then return -1
   return listBox~delete(index)

::method getCurrentListIndex unguarded
   use strict arg id
   listBox = self~newListBox(id)
   if listBox == .nil then return -1
   return listBox~selectedIndex

::method setCurrentListIndex unguarded
   use strict arg id, ndx = 0
   listBox = self~newListBox(id)
   if listBox == .nil then return -1
   return listBox~selectIndex(ndx)

::method getListItems unguarded
   use strict arg id
   listBox = self~newListBox(id)
   if listBox == .nil then return -1
   return listBox~items

::method changeListEntry unguarded
   use strict arg id, index = (self~getCurrentListIndex(id)), newString
   if index <= 0 then return -1
   self~deleteListEntry(id, index)
   return self~insertListEntry(id, index, newString)

::method listDrop unguarded
   use strict arg id
   listBox = self~newListBox(id)
   if listBox == .nil then return -1
   return listBox~deleteAll


::method enableControl unguarded external "LIBRARY oodialog pbdlg_enableDisableControl"
::method disableControl unguarded external "LIBRARY oodialog pbdlg_enableDisableControl"
::method showControl unguarded external "LIBRARY oodialog pbdlg_showControl"
::method hideControl unguarded external "LIBRARY oodialog pbdlg_showControl"
::method showControlFast unguarded external "LIBRARY oodialog pbdlg_showControl"
::method hideControlFast unguarded external "LIBRARY oodialog pbdlg_showControl"
::method showWindow unguarded external "LIBRARY oodialog pbdlg_showWindow"
::method showWindowFast unguarded external "LIBRARY oodialog pbdlg_showWindow"
::method hideWindow unguarded external "LIBRARY oodialog pbdlg_showWindow"
::method hideWindowFast unguarded external "LIBRARY oodialog pbdlg_showWindow"

::method focusControl unguarded external "LIBRARY oodialog pbdlg_focusControl"
::method setFocusToWindow unguarded external "LIBRARY oodialog pbdlg_setFocus"
::method tabToNext unguarded external "LIBRARY oodialog pbdlg_tabTo"
::method tabToPrevious unguarded external "LIBRARY oodialog pbdlg_tabTo"
::method setFocus unguarded external "LIBRARY oodialog pbdlg_setFocus"
::method getFocus unguarded external "LIBRARY oodialog pbdlg_getFocus"
::method setTabStop unguarded external "LIBRARY oodialog pbdlg_setTabGroup"
::method setGroup unguarded external "LIBRARY oodialog pbdlg_setTabGroup"
::method center unguarded external "LIBRARY oodialog pbdlg_center"

::method getMenuBar
  return self~menuBar

::method hasMenuBar
  return self~menuBar \== .nil & self~isLinked

::method createToolTip unguarded external "LIBRARY oodialog pbdlg_createToolTip"
::method newPushButton unguarded external "LIBRARY oodialog pbdlg_newControl"
::method newRadioButton unguarded external "LIBRARY oodialog pbdlg_newControl"
::method newCheckBox unguarded external "LIBRARY oodialog pbdlg_newControl"
::method newGroupBox unguarded external "LIBRARY oodialog pbdlg_newControl"
::method newEdit unguarded external "LIBRARY oodialog pbdlg_newControl"
::method newComboBox unguarded external "LIBRARY oodialog pbdlg_newControl"
::method newListBox unguarded external "LIBRARY oodialog pbdlg_newControl"
::method newReBar unguarded external "LIBRARY oodialog pbdlg_newControlEx"
::method newScrollBar unguarded external "LIBRARY oodialog pbdlg_newControl"
::method newStatic unguarded external "LIBRARY oodialog pbdlg_newControl"
::method newStatusBar unguarded external "LIBRARY oodialog pbdlg_newControlEx"
::method newToolBar unguarded external "LIBRARY oodialog pbdlg_newControlEx"
::method newToolTip unguarded external "LIBRARY oodialog pbdlg_newToolTip"
::method newTreeView unguarded external "LIBRARY oodialog pbdlg_newControl"
::method newListView unguarded external "LIBRARY oodialog pbdlg_newControl"
::method newTab unguarded external "LIBRARY oodialog pbdlg_newControl"
::method newProgressBar unguarded external "LIBRARY oodialog pbdlg_newControl"
::method newTrackBar unguarded external "LIBRARY oodialog pbdlg_newControl"
::method newMonthCalendar unguarded external "LIBRARY oodialog pbdlg_newControlEx"
::method newDateTimePicker unguarded external "LIBRARY oodialog pbdlg_newControlEx"
::method newUpDown unguarded external "LIBRARY oodialog pbdlg_newControlEx"
::method newControl unguarded external "LIBRARY oodialog pbdlg_getNewControl"           -- Do not document for 4.2.0, maybe doc later
::method dumpMessageTable unguarded external "LIBRARY oodialog pbdlg_dumpMessageTable"  -- Do not document for 4.2.0, maybe doc later

::method test unguarded external "LIBRARY oodialog pbdlg_test"

-- DEPRECATED  (to end of file)

::method deInstall
  return 0

-- There is no longer a message queue.
::method run unguarded private
   do while \ self~finished
      self~handleMessages
   end

::method handleMessages unguarded
   j = SysSleep(.010)

::method clearMessages unguarded
::method peekDialogMessage unguarded
   return ""

-- There is no longer a DIALOGADMIN block.
::method dump
    say "dump() deprecated."

-- adm was never documented and should just be removed, but it would have been
-- needed in the dump() method which was documented. (Even though the
-- documentation never explained where a 'dialogadmin' block would come from.)
::attribute adm get
  return 0

::method connectEntryLine unguarded
   forward message 'connectEdit'
::method connectMultiListBox unguarded
   forward message 'connectListBox'
::method connectTreeControl unguarded
   forward message 'connectTreeView'
::method connectListControl unguarded
   forward message 'connectListView'
::method connectSliderControl unguarded
   forward message 'connectTrackBar'
::method connectTabControl unguarded
   forward message 'connectTab'

::method getEntryLine unguarded
   forward message 'getEditData'
::method getListLine unguarded
   forward message 'getListBoxData'
::method getComboLine unguarded
   forward message 'getComboBoxData'
::method getCheckBox unguarded
   forward message 'getCheckBoxData'
::method getRadioButton unguarded
   forward message 'getRadioButtonData'
::method getMultiList unguarded
   forward message 'getListBoxData'
::method getValue unguarded
   forward message 'getControlData'
::method getAttrib unguarded
   forward message 'getDataAttribute'

::method setEntryLine unguarded
   forward message 'setEditData'
::method setListLine unguarded
   forward message 'setListBoxData'
::method setComboLine unguarded
   forward message 'setComboBoxData'
::method setCheckBox unguarded
   forward message 'setCheckBoxData'
::method setRadioButton unguarded
   forward message 'setRadioButtonData'
::method setMultiList unguarded
   forward message 'setListBoxData'
::method setValue unguarded
   forward message 'setControlData'
::method setAttrib unguarded
   forward message 'setDataAttribute'

::method setWindowTitle unguarded
   forward message 'setWindowText'
::method windowTitle unguarded
   forward message 'getWindowText'
::method setStaticText unguarded
   forward message 'setControlText'

::method sendMessageToItem unguarded
   forward message "sendMessageToControl"
::method getItem unguarded
   forward message "getControlHandle"
::method itemTitle unguarded  -- Present but never documented in early ooDialog
   forward message 'getControlText'
::method enableItem unguarded
   forward message 'enableControl'
::method disableItem unguarded
   forward message 'disableControl'
::method showItem unguarded
   forward message "showControl"
::method hideItem unguarded
   forward message "hideControl"
::method showItemFast unguarded
   forward message "showControlFast"
::method hideItemFast unguarded
   forward message "hideControlFast"
::method focusItem unguarded
   forward message "focusControl"

::method getStaticControl unguarded
   forward message 'newStatic'
::method getButtonControl unguarded
   forward message 'newPushButton'
::method getRadioControl unguarded
   forward message 'newRadioButton'
::method getCheckControl unguarded
   forward message 'newCheckBox'
::method getGroupBox unguarded
   forward message 'newGroupBox'
::method getEditControl unguarded
   forward message 'newEdit'
::method getComboBox unguarded
   forward message 'newComboBox'
::method getListBox unguarded
   forward message 'newListBox'
::method getScrollBar unguarded
   forward message 'newScrollBar'
::method getTreeControl unguarded
   forward message 'newTreeView'
::method getListControl unguarded
   forward message 'newListView'
::method getTabControl unguarded
   forward message 'newTab'
::method getProgressBar unguarded
   forward message 'newProgressBar'
::method getSliderControl unguarded
   forward message 'newTrackBar'

::method getTextSize unguarded
   forward message "getTextSizeDlg" continue
   return result~width result~height


/**
 * Windows Dialog Interface for Open Object Rexx (ooRexx.)
 *
 * Resource Script Dialog Class (RcDialog)
 *
 * Provides support for creating a dialog defined in a resource script file,
 * (most commonly a *.rc file, but *.dlg is also common.)
 */
::class 'RcDialog' subclass UserDialog public

::method init
  use strict arg rcFile, idDlg = '', initData. = .nil, includeFile = "", options = "", expected = 200, ownerExtra = .nil

  newArgs = .array~new(5)
  if arg(3, 'E') then newArgs[1] = arg(3)
  if arg(4, 'E') then newArgs[2] = arg(4)
  newArgs[3] = rcFile
  if arg(2, 'E') then newArgs[4] = idDlg
  if arg(5, 'E') then newArgs[5] = ownerExtra

  forward class (super) arguments (newArgs) continue
  if result <> 0 then return result

  self~initCode = self~load(rcFile, idDlg, options, expected)

  return self~initCode


/**
 * Windows Dialog Interface for Open Object Rexx (ooRexx)
 *
 * Menu Classes
 *
 * Provides support for all types of Windows Menus.
 */


/* class: Menu - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*\
     A mix in class implementing functionality that is common to all menus.
\* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
::class 'Menu' public mixinclass Object

::method connectCommandEvent class external "LIBRARY oodialog menu_connectCommandEvent_cls"

::method menuInit private external "LIBRARY oodialog menu_menuInit_pvt"
::method unInit external "LIBRARY oodialog menu_uninit"

::attribute wID get external "LIBRARY oodialog menu_wID"
::attribute hMenu get external "LIBRARY oodialog menu_getHMenu"

-- TODO NEED appendPopup() and appendItem()  (note you can not append a separator, or can you?)

-- TODO there are some methods where the C code was there but there are no
-- Rexx methods to match.  SetItemType, SetPopupType, SetItemState, SetPopupType
-- These methods would take a combination of keywords.  The parsing of the
-- keywords is already implmented.

::method check external "LIBRARY oodialog menu_check"
::method checkRadio external "LIBRARY oodialog menu_checkRadio"
::method connectAllCommandEvents external "LIBRARY oodialog menu_connectAllCommandEvents"
::method connectCommandEvent external "LIBRARY oodialog menu_connectCommandEvent"
::method connectMenuEvent external "LIBRARY oodialog menu_connectMenuEvent"
::method connectSomeCommandEvents external "LIBRARY oodialog menu_connectSomeCommandEvents"
::method deletePopup external "LIBRARY oodialog menu_deletePopup"
::method destroy external "LIBRARY oodialog menu_destroy"
::method disable external "LIBRARY oodialog menu_disable"
::method enable external "LIBRARY oodialog menu_enable"
::method getAutoConnectStatus external "LIBRARY oodialog menu_getAutoConnectStatus"
::method getCount external "LIBRARY oodialog menu_getCount"
::method getHandle external "LIBRARY oodialog menu_getHMenu"
::method getHelpID external "LIBRARY oodialog menu_getHelpID"
::method getID external "LIBRARY oodialog menu_getID"
::method getItemState external "LIBRARY oodialog menu_getItemState"
::method getMaxHeight external "LIBRARY oodialog menu_getMaxHeight"
::method getMenuHandle external "LIBRARY oodialog menu_getMenuHandle"
::method getPopup unguarded external "LIBRARY oodialog menu_getPopup"
::method getText external "LIBRARY oodialog menu_getText"
::method getType external "LIBRARY oodialog menu_getItemType"
::method gray external "LIBRARY oodialog menu_disable"
::method hilite external "LIBRARY oodialog menu_hilite"
::method insertItem unguarded external "LIBRARY oodialog menu_insertItem"
::method insertPopup unguarded external "LIBRARY oodialog menu_insertPopup"
::method insertSeparator unguarded external "LIBRARY oodialog menu_insertSeparator"
::method isChecked external "LIBRARY oodialog menu_isChecked"
::method isCommandItem external "LIBRARY oodialog menu_isCommandItem"
::method isDisabled external "LIBRARY oodialog menu_isDisabled"
::method isEnabled external "LIBRARY oodialog menu_isEnabled"
::method isGrayed external "LIBRARY oodialog menu_isDisabled"
::method isPopup external "LIBRARY oodialog menu_isPopup"
::method isSeparator external "LIBRARY oodialog menu_isSeparator"
::method isValidItemID external "LIBRARY oodialog menu_isValidItemID"
::method isValidMenu external "LIBRARY oodialog menu_isValidMenu"
::method isValidMenuHandle external "LIBRARY oodialog menu_isValidMenuHandle"
::method itemTextToMethodName external "LIBRARY oodialog menu_itemTextToMethodName"
::method releaseMenuHandle external "LIBRARY oodialog menu_releaseMenuHandle"
::method removeItem external "LIBRARY oodialog menu_removeItem"
::method removePopup external "LIBRARY oodialog menu_removePopup"
::method removeSeparator external "LIBRARY oodialog menu_removeSeparator"
::method setAutoConnection external "LIBRARY oodialog menu_setAutoConnection"
::method setHelpID external "LIBRARY oodialog menu_setHelpID"
::method setID external "LIBRARY oodialog menu_setID"
::method setMaxHeight external "LIBRARY oodialog menu_setMaxHeight"
::method setText external "LIBRARY oodialog menu_setText"
::method unCheck external "LIBRARY oodialog menu_unCheck"
::method unHilite external "LIBRARY oodialog menu_unHilite"

::method test external "LIBRARY oodialog menu_test"

/* class: MenuBar- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*\
     A mix in class implementing functionality that is common to all menu bars.
\* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
::class 'MenuBar' public mixinclass Menu

::method attachTo external "LIBRARY oodialog menuBar_attachTo"
::method detach external "LIBRARY oodialog menuBar_detach"
::method isAttached external "LIBRARY oodialog menuBar_isAttached"
::method redraw external "LIBRARY oodialog menuBar_redraw"
::method replace external "LIBRARY oodialog menuBar_replace"


/** unInit()
 * A menu that is not assigned to a window must be destroyed by the application
 * when it closes.  On the other hand, menus assigned to a window are destroyed
 * by the system when the window is destroyed.
 */
::method unInit
  forward class (.Menu)

/* class: SystemMenu - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*\
     A system menu class.  System menus are also known as window or control
     menus.  It is the menu that appears when clicking on the icon in the upper
     left corner of a window.
\* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
::class 'SystemMenu' public subclass Object inherit Menu

::constant WM_SYSCOMMAND     "0x0112"

-- Use decimal value to allow comparison in event handlers.
::constant SC_SIZE           61440
::constant SC_MOVE           61456
::constant SC_MINIMIZE       61472
::constant SC_MAXIMIZE       61488
::constant SC_NEXTWINDOW     61504
::constant SC_PREVWINDOW     61520
::constant SC_CLOSE          61536
::constant SC_VSCROLL        61552
::constant SC_HSCROLL        61568
::constant SC_MOUSEMENU      61584
::constant SC_KEYMENU        61696
::constant SC_ARRANGE        61712
::constant SC_RESTORE        61728
::constant SC_TASKLIST       61744
::constant SC_SCREENSAVE     61760
::constant SC_HOTKEY         61776
::constant SC_DEFAULT        61792
::constant SC_MONITORPOWER   61808
::constant SC_CONTEXTHELP    61824
::constant SC_SEPARATOR      61455

::method init external "LIBRARY oodialog sysMenu_init"
::method revert external "LIBRARY oodialog sysMenu_revert"
::method unInit
  forward class (.Menu)



/* class: BinaryMenuBar- - - - - - - - - - - - - - - - - - - - - - - - - - - -*\
     A menu bar menu created from a binary resource, or created as an empty
     menu.
\* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
::class 'BinaryMenuBar' public subclass Object inherit MenuBar

::method init external "LIBRARY oodialog binMenu_init"
::method unInit
  forward class (.Menu)


/* class: PopupMenu- - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*\
     A popup menu.  (Popup menus are also called, at various times, submenus,
     drop down menus, or context menus.)
\* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
::class 'PopupMenu' public subclass Object inherit Menu

::method connectContextMenu class external "LIBRARY oodialog popMenu_connectContextMenu_cls"

::method init external "LIBRARY oodialog popMenu_init"

::method assignTo external "LIBRARY oodialog popMenu_assignTo"
::method connectContextMenu external "LIBRARY oodialog popMenu_connectContextMenu"
::method isAssigned external "LIBRARY oodialog popMenu_isAssigned"
::method show external "LIBRARY oodialog popMenu_show"
::method track external "LIBRARY oodialog popMenu_track"

::method unInit
  forward class (.Menu)

/* class: MenuTemplate - - - - - - - - - - - - - - - - - - - - - - - - - - - -*\
    A mix in class supplying the funtionality to create a menu template in
    memory.  This a private, internal use only, class.  The methods are doc-
    umented as part of the UserMenuBar, the class itself is not documented.
\* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
::class 'MenuTemplate' private mixinclass Object

::method addPopup external "LIBRARY oodialog menuTemplate_addPopup"
::method addItem external "LIBRARY oodialog menuTemplate_addItem"
::method addSeparator external "LIBRARY oodialog menuTemplate_addSeparator"
::method isComplete external "LIBRARY oodialog menuTemplate_isComplete"


/* class: UserMenuBar- - - - - - - - - - - - - - - - - - - - - - - - - - - - -*\
     A menu bar menu whose initial menu template is created in memory though
     user (programmer) defined statements.
\* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
::class 'UserMenuBar' public subclass Object inherit MenuBar MenuTemplate

::method init external "LIBRARY oodialog userMenu_init"
::method complete external "LIBRARY oodialog userMenu_complete"
::method unInit
  forward class (.Menu)


/* class: ScriptMenuBar- - - - - - - - - - - - - - - - - - - - - - - - - - - -*\
     A menu bar menu whose initial menu template is created in memory by parsing
     a resouce script file.
\* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
::class 'ScriptMenuBar' public subclass Object inherit MenuBar MenuTemplate

::method init external "LIBRARY oodialog scriptMenu_init"
::method resolveSymbolicID external "LIBRARY oodialog global_resolveSymbolicID"
::method unInit
  forward class (.Menu)

/** load() Parses a menu definition in a resource script file and loads it into
 *         memory (through a MenuTemplate.)  The MENU resource definition
 *         statement looks like:
 *
 *    menuID MENU  [[optional-statements]]
 *
 *    We ignore the optional statements. menuID can be a number, a symbolic ID
 *    that resolves to a number, or a string name.
 *
 *    If noMenuID is set to .true we simply take the first menu found.  If
 *    menuid is set to -1 then we are looking for a string name that matches
 *    menuName.  Otherwise we match menuid.  Syntax errors are raised for all
 *    problems, including not finding the menu.  If no error is raised, the
 *    menu is guaranteed to be loaded into memory.
 *
 *    Assumes that the caller has already parsed the file for symbolic ID
 *    defintions.
 */
::method load private
  use strict arg resfile, menuid, connect, count, noMenuID = .false, menuName = ""

  signal on syntax

  file = SysSearchPath("PATH", resfile)
  if file == "" then do
    msg = 'Unable to find resource script file "'resFile'"'
    raise syntax 98.900 array (msg)
  end

  f = .stream~new(file)
  op = f~open(read)
  if op \= "READY:" then do
    msg = 'Resource script file "'resFile'" is not readable:' op
    raise syntax 98.900 array (msg)
  end

  found = 0; n = 0
  menuName = menuName~translate
  isMenuEx = .false
  fl = f~lines
  do while found = 0, fl > 0
     do while n = 0, fl > 0
        s = f~linein; fl -= 1
        keyWord = s~word(2)
        if keyWord == "MENU" |  keyWord == "MENUEX" then n = 2
     end

     if f~lines == 0 then do
       -- We read the whole file and never found a MENU statement.
       f~close

       if noMenuID then subMsg = 'no MENU statement found'
       else if menuName \== "" then subMsg = 'no MENU statement for menuid "'menuName'"'
       else subMsg = 'no MENU statement for menuid "'menuid'"'

       msg = 'Error: script file "'resFile'"' subMsg
       raise syntax 98.900 array (msg)
     end

     if noMenuID then found = 1
     else if menuid == -1, s~word(n-1)~translate == menuName then found = 1
     else if menuid \== -1, self~resolveSymbolicID(s~word(n-1)) == menuid then found = 1
     else n = 0

     if n \= 0, keyWord == "MENUEX" then isMenuEx = .true
  end

  s = f~linein; fl -= 1
  do while s~wordpos("BEGIN") = 0, s~pos("{") = 0, fl > 0
     s = f~linein; fl -= 1
  end

  if f~lines == 0 then do
     -- We read the whole file and never found the begin or bracket.
     f~close
     msg = 'Error: script file "'resFile'" no BEGIN or "{" for MENU statement'
     raise syntax 98.900 array (msg)
  end

  rcarray = .array~new(50)
  bracket = 1
  cur = 0
  endcount = 0

  prevs = ""
  s = f~linein; fl -= 1
  do while bracket > 0, fl >= 0
     if s~wordpos("END") > 0 | s~pos("}") > 0 then do
       bracket -= 1;
       endcount += 1
       cur += 1
       rcarray[cur] = s
     end
     else if s~wordpos("BEGIN") > 0 | s~pos("{") > 0 then do
       bracket += 1;
       cur += 1
       rcarray[cur] = s
     end
     else if s~strip \= "" then do
       cur += 1
       rcarray[cur] = s
     end
     s = f~linein; fl -= 1
  end

  f~close
  arrcount = cur

  if (count < cur - endcount) then do
    msg = 'Menu in script file "'resFile'"contains more items ('cur - endcount') than allocated ('count')'
    raise syntax 98.900 array (msg)
  end

  if isMenuEx then return self~parseMenuEx(rcarray, arrcount, connect)
  else return self~parseMenu(rcarray, arrcount, connect)

syntax:
  c = condition('O')
  if c~traceBack \== .nil then c~traceBack~empty
  raise propagate

::method parseMenu private
  use strict arg rcarray, arrcount, connect

  do i = 1 to arrcount
     s = rcarray[i]

     select
        when s~wordPos("POPUP") > 0 then do
           parse var s type '"'name'"'    "," opt

           j = i + 1;
           bracket = 0
           do until bracket = 0
             if rcarray[j]~wordPos("BEGIN") > 0 | rcarray[j]~pos("{") > 0 then
               bracket += 1
             else if rcarray[j]~wordPos("END") > 0 | rcarray[j]~pos("}") > 0 then
               bracket -= 1
             j += 1
           end

           if rcarray[j]~wordPos("END") > 0 | rcarray[j]~pos("}") > 0 then opt = opt || " END"
           self~addPopup(0, name, opt, 0)
        end

        when s~wordPos("SEPARATOR") > 0 then do
           parse var s type sep opt
           if rcarray[i+1]~wordPos("END") > 0 | rcarray[i+1]~pos("}") > 0 then opt = opt || " END"
           self~addSeparator(0, opt)
        end

        when s~wordPos("MENUITEM") > 0 then do
           parse var s type '"'name'"'    "," id "," opt
           id = id~strip
           if rcarray[i+1]~wordPos("END") > 0 | rcarray[i+1]~pos("}") > 0 then opt = opt || " END"
           if connect then
              self~addItem(id, name, opt, self~itemTextToMethodName(name))
           else
              self~addItem(id, name, opt)
        end

        when s~wordPos("END") > 0 | s~pos("}") > 0 | s~wordPos("BEGIN") > 0 | s~pos("{") > 0 then nop;

        otherwise do
          msg = "Error parsing MENU definition." || '  ' || "Resource file:" f || '  ' || "Line:" s
          raise syntax 98.900 array (msg)
        end
    end /*select 1*/
  end /* do while */

  return 0

::method mergeTypeState private
  use strict arg type, state

  opt  = ""
  if type~wordPos("MFT_BITMAP") > 0 then opt = "BITMAP"
  else if type~wordPos("MFT_SEPARATOR") > 0 then opt = "SEPARATOR"
  else if type~wordPos("MFT_STRING") > 0 then opt = "STRING"

  if type~wordPos("MFT_MENUBARBREAK") > 0 then opt ||= " MENUBARBREAK"
  if type~wordPos("MFT_MENUBREAK") > 0 then opt    ||= " MENUBREAK"
  if type~wordPos("MFT_OWNERDRAW") > 0 then opt    ||= " OWNERDRAW"
  if type~wordPos("MFT_RADIOCHECK") > 0 then opt   ||= " RADIOCHECK"
  if type~wordPos("MFT_RIGHTJUSTIFY") > 0 then opt ||= " RIGHTJUSTIFY"
  if type~wordPos("MFT_RIGHTORDER") > 0 then opt   ||= " RIGHTORDER"

  if state~wordPos("MFS_CHECKED") > 0 then opt ||= " CHECKED"
  if state~wordPos("MFS_DEFAULT") > 0 then opt ||= " DEFAULT"
  if state~wordPos("MFS_DISABLED") > 0 then opt ||= " DISABLED"
  if state~wordPos("MFS_ENABLED") > 0 then opt ||= " ENABLED"
  if state~wordPos("MFS_GRAYED") > 0 then opt ||= " GRAYED"
  if state~wordPos("MFS_HILITE") > 0 then opt ||= " HILITE"
  if state~wordPos("MFS_UNCHECKED") > 0 then opt ||= " UNCHECKED"
  if state~wordPos("MFS_UNHILITE") > 0 then opt ||= " UNHILITE"

  return opt


::method parseMenuEx private
  use strict arg rcarray, arrcount, connect

  do i = 1 to arrcount
     s = rcarray[i]

     select
        when s~word(1) == "POPUP" then do
           parse var s type '"'name'"' "," id "," type "," state "," helpID
           id = id~strip; helpID = id~strip

           j = i + 1;
           bracket = 0
           do until bracket = 0
             if rcarray[j]~wordPos("BEGIN") > 0 | rcarray[j]~pos("{") > 0 then
               bracket += 1
             else if rcarray[j]~wordPos("END") > 0 | rcarray[j]~pos("}") > 0 then
               bracket -= 1
             j += 1
           end

           opt = self~mergeTypeState(type, state)
           if rcarray[j]~wordPos("END") > 0 | rcarray[j]~pos("}") > 0 then opt ||= " END"

           self~addPopup(id, name, opt, helpID)
        end

        when s~word(1) == "MENUITEM" then do
           parse var s type '"'name'"' "," id "," type "," state
           id = id~strip

           opt = self~mergeTypeState(type, state)
           if rcarray[i+1]~wordPos("END") > 0 | rcarray[i+1]~pos("}") > 0 then opt ||= " END"

           if opt~wordPos("SEPARATOR") > 0 then do
             self~addSeparator(id, opt)
           end
           else do
             if connect then
                self~addItem(id, name, opt, self~itemTextToMethodName(name))
             else
                self~addItem(id, name, opt)
           end
        end

        when s~wordPos("END") > 0 | s~pos("}") > 0 | s~wordPos("BEGIN") > 0 | s~pos("{") > 0 then nop;

        otherwise do
          msg = "Error parsing MENUEX definition." || '  ' || "Resource file:" f || '  ' || "Line:" s
          raise syntax 98.900 array (msg)
        end
    end /*select i = 1*/
  end /* do while */

  return 0



/**
 * Windows Dialog Interface for Open Object Rexx (ooRexx.)
 *
 * Resource Dialog Class.
 */

-- This class extends the 'PlainBaseDialog' class.  Because of backwards
-- compatibility we need to do this through the deprecated BaseDialog.
-- BaseDialog will be removed in the future.  Do NOT use BaseDialog in any code.
::class 'ResDialog' subclass BaseDialog public

::method init external "LIBRARY oodialog resdlg_init"

-- Documented "internal use only" in 3.2.0 - Do not document.
::method startIt
   use strict arg icon = 0, modeless = .false

   icon = self~resolveIconID(icon)
   if \ modeless~datatype('O') then modeless = .false

   if self~startDialog(self~library, self~resourceID, icon, modeless) then do
      -- if autodetection is on, create the data attributes
      if self~autoDetect then do
         ids = self~getDataTableIDs
         do id over ids
            text = self~getControlText(id)
            self~addAttribute(id, text)
         end
      end
      self~initDialog
      return .true
   end

   return .false

::method startDialog private external "LIBRARY oodialog resdlg_startDialog_pvt"
::method getDataTableIDs private external "LIBRARY oodialog resdlg_getDataTableIDs_pvt"

-- DEPRECATED
::method setMenu
  use strict arg id
  menuBar = .BinaryMenuBar~new(self, id, 0, self)
  if menuBar == 0 then return .false
  self~menuBar = menuBar
  .constDir~putAll(self~constDir)
  return .true


/**
 * Windows Dialog Interface for Open Object Rexx (ooRexx.)
 *
 * User Dialog Class.
 */

-- This class extends the 'PlainBaseDialog' class.  Because of backwards
-- compatibility we need to do this through the deprecated BaseDialog.
-- BaseDialog will be removed in the future.  Do NOT use BaseDialog in any code.
::class 'UserDialog' subclass BaseDialog public inherit DynamicDialog

::method init external "LIBRARY oodialog userdlg_init"

-- Called from createStaticText() in oodUser.cpp
::method setStaticTextAttribute                       -- Internal use only, do not document
  use arg id, text

  atrName = self~dataConnection[id]
  if atrName \== .nil then self~sendWith(atrName || '=', .array~of(text))

  if self~useStem then self~dlgData[id] = text

::method test external "LIBRARY oodialog userdlg_test"

-- DEPRECATED menu bar methods.  Use the Menu classes directly.
::method setMenu
    menuBar = self~menuBar

    .local~systemErrorCode = 0
    if menuBar == .nil then do
      .local~systemErrorCode = 1 -- ERROR_INVALID_FUNCTION (1) -> Incorrect function.
      return .false
    end

    if menuBar~isA(.UserMenuBar) then do
      if \ menuBar~complete then do
        self~menuBar = .nil
        return .false
      end
    end

    if \ menuBar~isA(.UserMenuBar), \ menuBar~isA(.ScriptMenuBar) then do
      .local~systemErrorCode = 1 -- ERROR_INVALID_FUNCTION (1) -> Incorrect function.
      return .false
    end

    return menuBar~attachTo(self)

::method createMenu
    use strict arg count = 100

    -- menuBar is either good, or a condition was raised.
    menuBar = .UserMenuBar~new(-1, 0, count)
    self~menuBar = menuBar
    .constDir~putAll(self~constDir)
    return .true;

::method addPopupMenu
    use strict arg name, opt = ""

    .local~systemErrorCode = 0
    if self~menuBar == .nil then do
      .local~systemErrorCode = 1 -- ERROR_INVALID_FUNCTION (1) -> Incorrect function.
      return .false
    end

    return self~menuBar~addPopup(0, name, opt, 0)

::method addMenuItem
    use strict arg name, id, opt = "", msgToRaise = .nil

    .local~systemErrorCode = 0
    if self~menuBar == .nil then do
      .local~systemErrorCode = 1 -- ERROR_INVALID_FUNCTION (1) -> Incorrect function.
      return .false
    end

    if arg(4, 'O') then return self~menuBar~addItem(id, name, opt)
    else return self~menuBar~addItem(id, name, opt, msgToRaise)

::method addMenuSeparator

    .local~systemErrorCode = 0
    if self~menuBar == .nil then do
      .local~systemErrorCode = 1 -- ERROR_INVALID_FUNCTION (1) -> Incorrect function.
      return .false
    end

    return self~menuBar~addSeparator(0)

::method loadMenu protected
  use strict arg resfile, menuid, loadopts = "", count = 50

  connect = .false
  if loadopts~caselessWordPos("CONNECTITEMS") <> 0 then connect = .true

  -- menuBar is either good, or a condition was raised.
  menuBar = .ScriptMenuBar~new(resFile, menuid, 0, count, connect)
  self~menuBar = menuBar
  .constDir~putAll(self~constDir)
  return 0

/**
 * Windows Dialog Interface for Open Object Rexx (ooRexx.)
 *
 * Contains deprecated classes that contain no methods, and deprecated classes
 * that will no longer be maintained.
 *
 * The empty classes are needed to provide backward compatibility for existing
 * programs where dialogs have, or may have, inherited the classes.
 *
 * MessageExtensions:  Its functionality is contained in the EventNotification
 *                     class.
 *
 * AdvancedControls:   Its functionality is now contained in the PlainBaseDialog
 *                     class.
 *
 * PlainUserDialog:    The plain user dialog is no different than the UserDialog
 *                     class.
 *
 * BaseDialog:         The base dialog is no different than the PlainBaseDialog
 *                     class.  Do NOT use BaseDialog in any code. It WILL be
 *                     removed in the future.
 *
 * These classes were a poor implementation and were both buggy and hard to
 * maintain.
 *
 * CategoryDialog:     Replace with the PropertySheetDialog class using one of
 *                     the Wizard styles.
 *
 * PropertySheet       Replace with the PropertySheetDialog / PropertySheetPage
 *                     dialogs, or some combination of ControlDialog
 *                     (ResControlDialog, RcControlDialog, UserControlDialog,)
 *                     and possibly the TabOwnerDialog dialogs.
 */

-- DEPRECATED
::class 'MessageExtensions' Mixinclass Object public

-- DEPRECATED
::class 'AdvancedControls' Mixinclass Object public

-- DEPRECATED
::class 'PlainUserDialog' subclass UserDialog public

-- DEPRECATED
::class 'BaseDialog' subclass PlainBaseDialog public

/* Deprecated */
::class 'CategoryDialog' subclass UserDialog public

-- A directory that contains internal data.  This should be private, but I'm not sure of the
-- consequences to existing programs if it is changed.  MM
::attribute catalog unguarded protected

::attribute staticID private
::attribute catX private
::attribute catY private
::attribute catCX private
::attribute catStyle private
::attribute catLabel private
::attribute catMax private
::attribute wizard private

-- arg cdstyle=[ "DROPDOWN" | "TOPLINE" | "NOBORDER" | "WIZARD"] */
::method init
   use arg dlgData., cdx, cdy, cdcx, cdstyle, cdtable, cdlabel, cdmax, includeFile

   newArgs = .array~new(2)
   if arg(1, 'E') then newArgs[1] = arg(1)
   if arg(9, 'E') then newArgs[2] = arg(9)
   forward class (super) arguments (newArgs) continue
   if result <> 0 then return result

   self~catalog = .directory~new
   self~catalog['count'] = 0
   self~catalog['page'] = .directory~new
   self~catalog['page']['font'] = ""
   self~catalog['page']['fsize'] = 0
   self~catalog['page']['style'] = ""
   self~catalog['page']['btnwidth'] = 0
   self~catalog['page']['leftbtntext'] = "&Backward"
   self~catalog['page']['rightbtntext'] = "&Forward"
   self~catalog['page']['expected'] = 200

   if arg(1,'o') = 1 then self~useStem = .false; else self~useStem = .true
   if arg(2,'o') = 1 then self~catX = 10; else self~catX = cdx
   if arg(3,'o') = 1 then self~catY = 4; else self~catY = cdy
   if arg(4,'o') = 1 then self~catCX = 0; else self~catCX = cdcx
   if arg(5,'o') = 1 then self~catStyle = ""; else self~catStyle = cdstyle~translate
   if arg(6,'o') = 1 then cdtable = ""
   if arg(7,"o") = 1 then self~catLabel = "Page:"; else self~catLabel = cdlabel
   if arg(8,"o") = 1 then self~catMax = 0; else self~catMax = cdmax

   if cdtable \= '' then
   do
      self~catalog['names'] = .array~new(10)
      parse var cdtable name ret
      i = 0
      do while name \= ""
         i = i + 1
         self~catalog['names'][i] = name
         parse var ret name ret
      end
      self~catalog['count'] = i
   end

   self~initCategories()    /* user overwrite */

   if cdtable = '' then
   do
      if self~catalog['count'] = 0 then
      do
         i = 0
         do ar over self~catalog['names']
            i = i +1
         end
         self~catalog['count'] = i
      end
   end

   if self~catStyle~wordpos("WIZZARD") > 0 | self~catStyle~wordpos("WIZARD") > 0 then do
      self~wizard = .true
      self~catStyle = self~catStyle~changestr("WIZZARD", "")
   end
   else self~wizard = .false

-- Documented "internal use only" in 3.2.0 - Do not document.
   self~catalog['id'] = .array~new(self~catalog['count'],100)
   self~catalog['base'] = .array~new(self~catalog['count'])
   self~catalog['handles'] = .array~new(self~catalog['count'])

   self~staticID = 9600

   return 0


-- Documented "internal use only" in 3.2.0 - Do not document.
::method startIt   /* don't call parent startIt */
   if self~dlgHandle = 0 then return 0
   self~initDialog
   return self~dlgHandle

::method defineDialog
   if self~basePtr = 0 then return 0
   if self~catStyle~wordpos('DROPDOWN') = 0 then
      do i = 9001 to (9000 + self~catalog['count'])
         self~connectButtonEvent(i, "CLICKED", "CHANGEPAGE")
      end
   else self~connectListBoxEvent(9001, "SELCHANGE", "CHANGEPAGE")

   do i = 1 to self~catalog['count']
      catnames.i = self~catalog['names'][i]
   end


-- Documented "internal use only" in 3.2.0 - Do not document.
   self~catalog['category'] = 0

   n = self~catStyle~wordpos("TOPLINE")
   if n > 0 then self~catMax = 1
   m = self~catStyle~wordpos("DROPDOWN")

   if (n > 0 | m > 0) & self~catStyle~wordpos('NOBORDER') = 0 then self~catStyle = self~catStyle||" NOBORDER"

   if self~catalog['page']['h'] = .nil then self~catalog['page']['h'] = self~sizeY - 40

   size = self~getTextSizeDu("Hg")
   textHeight = size~height

   if self~catCX = 0 & n = 0 then  /* dropdown or none */
   do
      do i = 1 to self~catalog['count']
         if self~catalog['page']['font'] <> "" then
              size = self~getTextSizeDlg(catnames.i,self~catalog['page']['font'],self~catalog['page']['fsize'])
         else
              size = self~getTextSizeDu(catnames.i)
         self~catCX = max(self~catCX,size~width)
      end
      if n = 0 then self~catCX = self~catCX + 20
   end

   if n > 0 | m > 0 then do  /* topline or dropdown */
      if self~catalog['page']['x'] = .nil then self~catalog['page']['x'] = 1
      if m > 0 then do
        if self~catalog['page']['y'] = .nil then self~catalog['page']['y'] = self~catY*2+textHeight+4
      end
      else if self~catalog['page']['y'] = .nil then self~catalog['page']['y'] = self~catY+textHeight+5

      if self~catalog['page']['w'] = .nil then self~catalog['page']['w'] = self~sizeX - 2
   end
   else do
      if self~catMax = 0 then do
        if self~catalog['page']['x'] = .nil then self~catalog['page']['x'] = self~catX+10+self~catCX
      end
      else
        if self~catalog['page']['x'] = .nil then self~catalog['page']['x'] = self~catX+10+self~catCX * ((self~catalog['count']-1)%self~catMax+1)

      if self~catalog['page']['y'] = .nil then self~catalog['page']['y'] = 5

      if self~catalog['page']['w'] = .nil then self~catalog['page']['w'] = self~sizeX - (self~catX+self~catCX+20)
   end

   self~categoryPage

   if m > 0 then do
      if self~catMax = 0 then self~catMax = 5
      if self~catalog['count'] < self~catMax then self~catMax = self~catalog['count']
      if self~catMax < self~catalog['count'] then
           if self~catLabel='' then
                self~createComboBox(9001, self~catX, self~catY, self~catCX, (self~catMax+1)*(textHeight+4), -
                                 self~catStyle~delword(m, 1) || " CAT VSCROLL")
           else self~createComboBoxInput(9001, self~catX, self~catY, , self~catCX, self~catMax,             -
                                         self~catLabel, self~catStyle~delword(m, 1) || " CAT VSCROLL")
      else if self~catLabel='' then
                self~createComboBox(9001, self~catX,self~catY,self~catCX,(self~catMax+1)*(textHeight+4),    -
                                    self~catStyle~delword(m, 1) || " CAT")
           else self~createComboBoxInput(9001, self~catX, self~catY, , self~catCX, self~catMax,             -
                                         self~catLabel, self~catStyle~delword(m, 1) || " CAT")
   end
   else do
      if (n >0) then newstyle = self~catStyle~delword(n, 1)
                else newstyle = self~catStyle
      if self~catalog['page']['font'] <> "" then
         self~createRadioButtonStem(9001, self~catX, self~catY, self~catCX, catnames., self~catMax,,
                           newstyle || " CAT",,self~catalog['page']['font'],self~catalog['page']['fsize'])
      else
         self~createRadioButtonStem(9001, self~catX, self~catY, self~catCX, catnames., self~catMax, newstyle || " CAT")
   end

   if \ self~startParentDialog(0, .false) then return 0

   do i = 1 to self~catalog['count']
      self~catalog['category'] = i
      p = self~catalog['page']

      -- Start the dialog template for this page.  (Ignore an error, an exception will be raised)
      self~CreateCategoryDialog(p['x'], p['y'], p['w'], p['h'],p['font'], p['fsize'], p['expected'])

      -- Invoke the user defined method with the same name as the page name.  This is where the
      -- dialog control items for this page are defined.
      self~send(self~catalog['names'][i]~space(0))

      -- Create the underlying Windows dialog.
      hChildDlg = self~startChildDialog(self~catalog['base'][i], i)
      self~catalog['base'][i] = 0
      self~catalog['handles'][i] = hChildDlg
   end

-- This method returns the current page index
::method currentCategory unguarded
   return self~catalog['category']

-- This method adds controls to CategoryDialog dialog itself.  The dialog that is the parent to
-- the child dialogs that make up the pages of the CategoryDialog.
::method categoryPage protected

   size = self~getTextSizeDu("Hg")
   textHeight = size~height

   if self~catStyle~wordpos("TOPLINE") > 0 then
      self~createBlackFrame(-1, 0, 2, self~sizeX, textHeight + (self~catY+2))
   else if self~catStyle~wordpos("DROPDOWN") > 0 then
      self~createBlackFrame(-1, 0, 2, self~sizeX, textHeight + (self~catY*2)+1)

   lbtext = self~catalog['page']['leftbtntext']
   rbtext = self~catalog['page']['rightbtntext']
   if lbtext~pos(" ") > 0 then lbtext = '"' || lbtext || '"'
   if rbtext~pos(" ") > 0 then rbtext = '"' || rbtext || '"'

   wizardTextIdMsg = lbtext" 11 PreviousPage" rbtext" 12 NextPage"
   y = self~sizeY - 15

   if (self~catalog['page']['btnwidth'] > 0) then do
      cx = self~catalog['page']['btnwidth']
      x = trunc(self~sizeX - self~catalog['page']['btnwidth'] * 2 - 15)

      self~createPushButtonGroup(x, y, cx, , "&Ok 1 OK &Cancel 2 CANCEL", 1, "DEFAULT")
      if self~wizard then self~createPushButtonGroup(5, y, cx,  , wizardTextIdMsg, 1, "")
   end
   else do
      self~createOkCancelRightBottom
      if self~wizard then self~createPushButtonGroup(5, y, , , wizardTextIdMsg, 1, "")
   end

   self~createBlackFrame(-1, 0, self~sizeY - 20, self~sizeX, 1)

::method createCategoryDialog private external "LIBRARY oodialog catdlg_createCategoryDialog"

::method initDialog
   /* set the mark to the first radio button */
   if self~catStyle~wordpos('DROPDOWN') > 0 then do
      do i = 1 to self~catalog['count']
         self~addComboEntry(9001, self~catalog['names'][i])
      end
      self~setComboBoxData(9001, self~catalog['names'][1])
   end
   else self~sendMessageToItem(9001,"0x000000F1",1,0)
   if self~wizard then self~disableItem(11)

   /* call InitXXX for each category if such a method exists */
   do i = 1 to self~catalog['count']
      self~catalog['category'] = i
      msg = "init" || self~catalog['names'][i]~space(0)
      -- Does user class provide the initXXX method? If so invoke it.
      if self~hasMethod(msg) then self~send(msg)
   end

   /* activate first page */
   self~catalog['category'] = 1
   self~showWindow(self~catalog['handles'][self~catalog['category']])

   /* */

::method initCategories protected
   return


   /* This method returs the currently selected page. Return value 1 means */
   /* the first page is selected. */

::method GetSelectedPage unguarded
   if self~catStyle~wordpos('DROPDOWN') = 0 then do
      np = 9001
      do while self~getRadioButtonData(np) = 0 & np < (9001 + self~catalog['count'])
         np = np + 1
      end
   end
   else do
      cur = self~getComboBoxData(9001)
      np = 1
      do while np <= ( self~catalog['count']) & cur \= self~catalog['names'][np]
         np = np + 1
      end
      if np > self~catalog['count'] then return 0
      np = np + 9000
   end
   return np-9000

   /* 'ChangePage' switch to the page 'NewPage' and shows it. */
   /* If 'NewPage is omitted the currently selected page will be activated - */
   /* (if not allready done). */


::method ChangePage unguarded
   use arg NewPage

   oldPage = self~catalog['category']
   /* if ChangePage is called automatically, 2 arg are passed (WParam and LParam) */
   if arg(2,'o') = 0 | NewPage > 9000 then NewPage = self~GetSelectedPage
   else do
      if self~catStyle~wordpos("DROPDOWN") = 0 then do
          /* SetRadioButton only works for registered radio buttons */
          /* uncheck the old radio button and check the new one */
          self~SendMessageToItem(9000+OldPage,"0x000000F1",0,0)
          self~SendMessageToItem(9000+NewPage,"0x000000F1",1,0)
      end
      else self~SetCurrentComboIndex(9001, NewPage)
   end
   if (NewPage = self~catalog['category']) | (NewPage < 1 | NewPage> self~catalog['count']) then return 0

   self~HideWindowFast(self~catalog['handles'][self~catalog['category']])
   self~catalog['category'] = NewPage
   if self~wizard then do
      if NewPage = 1 then do
         self~DisableItem(11)
         self~EnableItem(12)
      end
      else if NewPage = self~catalog['count'] then do
         self~EnableItem(11)
         self~DisableItem(12)
      end
      else do
         self~EnableItem(11)
         self~EnableItem(12)
      end
   end
   self~ShowWindow(self~catalog['handles'][self~catalog['category']])

   self~PageHasChanged(oldPage, NewPage)
   return NewPage

::method PageHasChanged unguarded
   use arg Oldpage, NewPage
   return

::method PreviousPage unguarded
   oldPage = self~CurrentCategory
   if oldPage > 1 then self~ChangePage(oldPage-1)

::method NextPage unguarded
   oldPage = self~CurrentCategory
   if oldPage < self~catalog['count'] then self~ChangePage(oldPage+1)


::method sendMessageToCategoryControl unguarded external "LIBRARY oodialog catdlg_sendMessageToCategoryControl"
::method categoryComboBox unguarded private
   use strict arg id, pageID
   if pageID == -1 then pageID = self~catalog['category']
   return self~newComboBox(id, pageID)

::method addCategoryComboEntry unguarded
   use strict arg id, string, pageID = (-1)
   comboBox = self~categoryComboBox(id, pageID)
   if comboBox == .nil then return -1
   else return comboBox~add(string)

::method insertCategoryComboEntry unguarded
   use strict arg id, index = 0, string, pageID = (-1)
   comboBox = self~categoyComboBox(id, pageID)
   if comboBox == .nil then return -1
   if arg(2, 'O') then return comboBox~insert( , string)
   else return comboBox~insert(index, string)

::method getCategoryComboEntry unguarded
   use strict arg id, index, pageID = (-1)
   comboBox = self~categoyComboBox(id, pageID)
   if comboBox == .nil then return -1
   return comboBox~getText(index)

::method findCategoryComboEntry unguarded
   use strict arg id, string, pageID = (-1)
   comboBox = self~categoryComboBox(id, pageID)
   if comboBox == .nil then return -1
   return comboBox~find(string)

::method categoryComboAddDirectory unguarded
   use strict arg id, drivepath, fileAttributes = "", pageID = (-1)
   comboBox = self~categoryComboBox(id, pageID)
   if comboBox == .nil then return -1
   return comboBox~addDirectory(drivePath, fileAttibutes)

::method deleteCategoryComboEntry unguarded
   use strict arg id, index = (-2), pageID = (-1)
   comboBox = self~categoryComboBox(id, pageID)
   if comboBox == .nil then return -1
   if index == -2 then index = self~getCurrentCategoryComboIndex(id, pageID)
   if index <= 0 then return -1
   return comboBox~delete(index)

::method getCurrentCategoryComboIndex unguarded
   use strict arg id, pageID = (-1)
   comboBox = self~categoryComboBox(id, pageID)
   if comboBox == .nil then return -1
   return comboBox~selectedIndex

::method setCurrentCategoryComboIndex unguarded
   use strict arg id, ndx = 0, pageID = (-1)
   comboBox = self~categoryComboBox(id, pageID)
   if comboBox == .nil then return -1
   return comboBox~selectIndex(ndx)

::method getCategoryComboItems unguarded
   use strict arg id, pageID = (-1)
   comboBox = self~categoryComboBox(id, pageID)
   if comboBox == .nil then return -1
   return comboBox~items

::method changeCategoryComboEntry unguarded
   use strict arg id, item = (-2), newEntry, pageID = (-1)
   if item == -2 then item = self~getCurrentCategoryComboIndex(id, pageID)
   if item <= 0 then return -1
   ret = self~deleteCategoryComboEntry(id, item, pageID)
   if ret <= 0 then return -1
   return self~insertCategoryComboEntry(id, item, newEntry, pageID)

::method categoryComboDrop unguarded
   use strict arg id, pageID = (-1)
   comboBox = self~categoryComboBox(id, pageID)
   if comboBox == .nil then return -1
   return comboBox~deleteAll


-- Methods to manipulate a list box.

::method categoryListBox unguarded private
   use strict arg id, pageID
   if pageID == -1 then pageID = self~catalog['category']
   return self~newListBox(id, pageID)

::method setCategoryListTabulators unguarded external "LIBRARY oodialog generic_setListTabulators"

::method addCategoryListEntry unguarded
   use strict arg id, text, pageID = (-1)
   listBox = self~categoryListBox(id, pageID)
   if listBox == .nil then return -1
   else return listBox~add(text)

::method insertCategoryListEntry unguarded
   use strict arg id, index = (-2), text, pageID = (-1)
   listBox = self~categoryListBox(id, pageID)
   if listBox == .nil then return -1
   if arg(2, 'O') then return listBox~insert( , text)
   else return listBox~insert(index, text)

::method findCategoryListEntry unguarded
   use strict arg id, text, pageID = (-1)
   listBox = self~categoryListBox(id, pageID)
   if listBox == .nil then return -1
   return listBox~find(text)

::method getCategoryListEntry unguarded
   use strict arg id, index, pageID = (-1)
   listBox = self~categoryListBox(id, pageID)
   if listBox == .nil then return -1
   return listBox~getText(index)

::method categoryListAddDirectory unguarded
   use strict arg id, drivePath, fileAttributes = "", pageID = (-1)
   listBox = self~categoryListBox(id, pageID)
   if listBox == .nil then return -1
   return listBox~addDirectory(drivePath, fileAttributes)

::method deleteCategoryListEntry unguarded
   use strict arg id, index = (-2), pageID = (-1)
   listBox = self~categoryListBox(id, pageID)
   if listBox == .nil then return -1
   if index == -2 then index = self~getCurrentCategoryListIndex(id, pageID)
   if index <= 0 then return -1
   return listBox~delete(index)

::method getCurrentCategoryListIndex unguarded
   use strict arg id, pageID = (-1)
   listBox = self~categoryListBox(id, pageID)
   if listBox == .nil then return -1
   return listBox~selectedIndex

::method setCurrentCategoryListIndex unguarded
   use strict arg id, ndx = 0, pageID = (-1)
   listBox = self~categoryListBox(id, pageID)
   if listBox == .nil then return -1
   return listBox~selectIndex(ndx)

::method getCategoryListItems unguarded
   use strict arg id, pageID = (-1)
   listBox = self~categoryListBox(id, pageID)
   if listBox == .nil then return -1
   return listBox~items

::method changeCategoryListEntry unguarded
   use strict arg id, item = (-2), newEntry, pageID = (-1)
   if item == -2 then item = self~getCurrentCategoryListIndex(id, pageID)
   if item <= 0 then return -1
   ret = self~deleteCategoryListEntry(id, item, pageID)
   if ret <= 0 then return -1
   return self~insertCategoryListEntry(id, item, newEntry, pageID)

::method categoryListDrop unguarded
   use strict arg id, pageID = (-1)
   listBox = self~categoryListBox(id, pageID)
   if listBox == .nil then return -1
   return listBox~deleteAll

::method setCategoryListWidthPx unguarded
   use strict arg id, pixels, pageID = (-1)
   listBox = self~categoryListBox(id, pageID)
   if listBox == .nil then return -1
   return listBox~setWidthPx(pixels)

::method getCategoryListWidthPx unguarded
   use strict arg id, pageID = (-1)
   listBox = self~categoryListBox(id, pageID)
   if listBox == .nil then return -1
   return listBox~widthPx

::method setCategoryListColumnWidthPx unguarded
   use strict arg id, pixels, pageID = (-1)
   listBox = self~categoryListBox(id, pageID)
   if listBox == .nil then return -1
   listBox~columnWidthPx = pixels
   return 0

::method setCategoryListItemHeightPx unguarded
   use strict arg id, pixels, pageID = (-1)
   listBox = self~categoryListBox(id, pageID)
   if listBox == .nil then return -1
   listBox~listItemHeightPx = pixels
   return 0

::method getCategoryListItemHeightPx unguarded
   use strict arg id, pageID = (-1)
   listBox = self~categoryListBox(id, pageID)
   if listBox == .nil then return -1
   return listBox~itemHeightPx

-- The following methods are generic methods to work with a dialog control.

::method getControlHandle unguarded
   use arg id, hDlg

   forward class (super) continue
   hwnd = result

   if hwnd = 0 & arg(2,'O') then do
       if \ id~datatype("W") then id = self~resolveSymbolicId(id)
       if id == -1 then return -1

       -- Try current page.
       hwnd = self~getControlHandle:super(id, self~catalog['handles'][self~catalog['category']])

       -- If still no good, try all pages.
       if hwnd = 0 then do i = 1 to self~catalog['count'] while hwnd = 0
           hwnd = self~getControlHandle:super(id, self~catalog['handles'][i])
       end
   end
   return hwnd

::method enableCategoryControl unguarded
   use strict arg id, category = ""
   if arg(2, 'O') | \ category~datatype("W") then category = self~catalog['category']  /* try current */

   hwnd = self~getControlHandle(id, self~catalog['handles'][category])
   if hwnd = 0 then return 1
   .Window~new(hwnd)~enable

::method disableCategoryControl unguarded
   use strict arg id, category = ""
   if arg(2, 'O') | \ category~datatype("W") then category = self~catalog['category']  /* try current */

   hwnd = self~getControlHandle(id, self~catalog['handles'][category])
   if hwnd = 0 then return 1
   .Window~new(hwnd)~disable

::method hideCategoryControl unguarded
   use strict arg id, category = ""
   if arg(2, 'O') | \ category~datatype("W") then category = self~catalog['category']  /* try current */

   hwnd = self~getControlHandle(id, self~catalog['handles'][category])
   if hwnd = 0 then return 1
   return .Window~new(hwnd)~hide

::method showCategoryControl unguarded
   use strict arg id, category = ""
   if arg(2, 'O') | \ category~datatype("W") then category = self~catalog['category']  /* try current */

   hwnd = self~getControlHandle(id, self~catalog['handles'][category])
   if hwnd = 0 then return 1
   .Window~new(hwnd)~show

::method resizeCategoryControl unguarded
   use strict arg id, width, height, showOptions = "", category = ""
   if arg(5,'O') | \ category~datatype("W") then category = self~catalog['category']  /* try current */

   hwnd = self~getControlHandle(id, self~catalog['handles'][category])
   if hwnd = 0 then return -1
   size = .Size~new(width, height)
   return .Window~new(hwnd)~resizeTo(size, showOptions)

::method moveCategoryControl unguarded
   use strict arg id, xPos, yPos, showOptions = "", category = ""
   if arg(5,'O') | \ category~dataType("W") then category = self~catalog['category']  /* try current */

   hwnd = self~getControlHandle(id, self~catalog['handles'][category])
   if hwnd = 0 then return -1
   pos = .Point~new(xPos, yPos)
   return .Window~new(hwnd)~moveTo(pos, showOptions)

::method setCategoryControlFont unguarded
   use strict arg id, hFont, bRedraw = 1, category = ""
   if arg(4, 'O') | \ category~datatype("W") then category = self~catalog['category']  /* try current */

   hCtrl = self~getControlHandle(id, self~catalog['handles'][category])
   msg   = self~WM_SETFONT
   return self~sendWinHandleMsg(msg, hFont, bRedraw, hCtrl)

::method focusCategoryControl unguarded
   use strict arg id, category = ""
   if arg(2,'O') | \ category~datatype("W") then category = self~catalog['category']  /* try current */

   hCtrl = self~getControlHandle(id, self~catalog['handles'][category])
   hDlg  = self~catalog['handles'][category]
   msg   = self~WM_NEXTDLGCTL
   return self~sendWinHandleMsg(msg, hCtrl, 1, hDlg)


-- The following methods are to set or get the 'data' of a single dialog control on one of
-- the category pages of the CategroyDialog.  It is  necessary to know the category page number
-- of the dialog control in order for to correctly identify the control.  If the page number
-- argument is omitted, it is assumed the page number is the current page number.

::method getControlDataPage unguarded external "LIBRARY oodialog catdlg_getControlDataPage"
::method getCheckBoxDataPage unguarded external "LIBRARY oodialog catdlg_getControlDataPage"
::method getRadioButtonDataPage unguarded external "LIBRARY oodialog catdlg_getControlDataPage"
::method getEditDataPage unguarded external "LIBRARY oodialog catdlg_getControlDataPage"
::method getListBoxDataPage unguarded external "LIBRARY oodialog catdlg_getControlDataPage"
::method getComboBoxDataPage unguarded external "LIBRARY oodialog catdlg_getControlDataPage"

::method setControlDataPage unguarded external "LIBRARY oodialog catdlg_setControlDataPage"
::method setStaticDataPage unguarded external "LIBRARY oodialog catdlg_setControlDataPage"
::method setCheckBoxDataPage unguarded external "LIBRARY oodialog catdlg_setControlDataPage"
::method setRadioButtonDataPage unguarded external "LIBRARY oodialog catdlg_setControlDataPage"
::method setEditDataPage unguarded external "LIBRARY oodialog catdlg_setControlDataPage"
::method setListBoxDataPage unguarded external "LIBRARY oodialog catdlg_setControlDataPage"
::method setComboBoxDataPage unguarded external "LIBRARY oodialog catdlg_setControlDataPage"

::method getDataAttribute unguarded
   use arg attributeName, category
   if arg(2, 'O') | \ category~datatype("W") then category = self~catalog['category']  /* try current */
   id = self~dataConnection~first
   do while (id \= .nil)
      if self~dataConnection[id] = attributeName then do
         data = self~getControlData(id, category)
         self~sendWith(attributeName'=', .array~of(data))
         return
      end
      id = self~dataConnection~Next(i)
   end

::method setDataAttribute unguarded
   use arg attributeName, category
   if arg(2, 'O') | \ category~datatype("W") then category = self~catalog['category']  /* try current category page */
   id = self~dataConnection~first
   do while (id \= .nil)
      if self~dataConnection[id] = attributeName then do
         data = self~send(attributeName)
         return self~setControlData(id, data, category)
      end
      id = self~dataConnection~next(id)
   end


::method getCategoryEntryLine unguarded
   forward message 'getEditDataPage'
::method getCategoryListLine unguarded
   forward message 'getListBoxDataPage'
::method getCategoryComboLine unguarded
   forward message 'getComboBoxDataPage'
::method getCategoryCheckBox unguarded
   forward message 'getCheckBoxDataPage'
::method getCategoryRadioButton unguarded
   forward message 'getRadioButtonDataPage'
::method getCategoryMultiList unguarded
   forward message 'getListBoxDataPage'
::method getCategoryValue unguarded
   forward message 'getControlDataPage'
::method getCategoryAttrib unguarded
   forward message 'getDataAttribute'
::method setCategoryStaticText unguarded
   forward message 'setStaticDataPage'
::method setCategoryEntryLine unguarded
   forward message 'setEditDataPage'
::method setCategoryListLine unguarded
   forward message 'setListBoxDataPage'
::method setCategoryComboLine unguarded
   forward message 'setComboBoxDataPage'
::method setCategoryCheckBox unguarded
   forward message 'setCheckBoxDataPage'
::method setCategoryRadioButton unguarded
   forward message 'setRadioButtonDataPage'
::method setCategoryMultiList unguarded
   forward message 'setListBoxDataPage'
::method setCategoryValue unguarded
   forward message 'setControlDataPage'
::method setCategoryAttrib unguarded
   forward message 'setDataAttribute'
::method sendMessageToCategoryItem unguarded
   forward message "sendMessageToCategoryControl"
::method getItem unguarded
   forward message 'getControlHandle'
::method enableCategoryItem unguarded
   forward message 'enableCategoryControl'
::method disableCategoryItem unguarded
   forward message 'disableCategoryControl'
::method hideCategoryItem unguarded
   forward message 'hideCategoryControl'
::method showCategoryItem unguarded
   forward message 'showCategoryControl'
::method setCategoryItemFont unguarded
   forward message "setCategoryControlFont"
::method focusCategoryItem unguarded
   forward message "focusCategoryControl"

::method resizeCategoryItem unguarded            -- Old method using dialog units, this is not accurate
   use strict arg id, width, height, showOptions = "", category = ""
   if arg(5, 'O') | \ category~datatype("W") then category = self~catalog['category']

   hwnd = self~getControlHandle(id, self~catalog['handles'][category])
   if hwnd = 0 then return -1
   size = .Size~new(trunc(width * self~factorX), trunc(height * self~factorY))
   return .Window~new(hwnd)~resizeTo(size, showOptions)

::method moveCategoryItem unguarded              -- Old method using dialog units, this is not accurate
   use strict arg id, xPos, yPos, showOptions = "", category = ""
   if arg(5, 'O') | \ category~datatype("W") then category = self~catalog['category']  /* try current */

   hwnd = self~getControlHandle(id, self~catalog['handles'][category])
   if hwnd = 0 then return -1
   pos = .Point~new(trunc(xPos * self~factorX), trunc(yPos * self~factorY))
   return .Window~new(hwnd)~moveTo(pos, showOptions)

::method getCategoryListItemHeight unguarded     -- Old method using dialog units, this is not accurate
   use strict arg id, pageID = (-1)
   pixels = self~getCategoryListItemHeightPx(id, pageID)
   if pixels <= 0 then return pixels
   else return pixels / self~factorY

::method setCategoryListWidth unguarded          -- Old method using dialog units, this is not accurate
   use strict arg id, dlgunits, pageID = (-1)
   pixels = dlgunits * self~factorX
   return self~setCategoryListWidthPx(id, pixels, pageID)

::method getCategoryListWidth unguarded          -- Old method using dialog units, this is not accurate
   use strict arg id, pageID = (-1)
   pixels = self~getListWidthPx(id, pageID)
   if pixels <= 0 then return pixels
   else return pixels / self~factorX

::method setCategoryListColumnWidth unguarded    -- Old method using dialog units, this is not accurate
   use strict arg id, dlgunits, pageID = (-1)
   pixels = dlgunits * self~factorX
   return self~setCategoryListColumnWidthPx(id, pixels, pageID)

::method setCategoryListItemHeight unguarded     -- Old method using dialog units, this is not accurate
   use strict arg id, dlgunits, pageID = (-1)
   pixels = dlgunits * self~factorY
   return self~setCategoryItemHeightPx(id, pixels, pageID)


/* Deprecated */
::class 'PropertySheet' subclass CategoryDialog public

::method init
   argarr = arg(1, "A")
   newarg = .array~new(argarr~items+1)
   if argarr~hasindex(1) = 1 then newarg[1] = argarr[1] /* dlgData */
   if argarr~hasindex(2) = 1 then newarg[6] = argarr[2] /* CatLabels */
   if argarr~hasindex(3) = 1 then newarg[2] = argarr[3] /* tabx */
   if argarr~hasindex(4) = 1 then newarg[3] = argarr[4] /* taby */
   if argarr~hasindex(5) = 1 then newarg[5] = argarr[5] /* options */
   if argarr~hasindex(6) = 1 then newarg[9] = argarr[6] /* include file */
   newarg[4] = 0
   forward class (super) arguments (newarg)


::method defineDialog
   if self~basePtr = 0 then return 0
   self~connectTabEvent(9001, "SELCHANGE", "CHANGEPAGE")

   do i = 1 to self~catalog['count']
      catnames.i = self~catalog['names'][i]
   end

   self~catalog['category'] = 0

   size = self~getTextSizeDu("Hg")

   self~catalog['page']['x'] = self~catx
   self~catalog['page']['y'] = self~caty
   self~catalog['page']['w'] = self~sizeX - self~catx*2
   self~catalog['page']['h'] = self~sizeY - self~catalog['page']['y'] - 27

   self~categoryPage

   p = self~catalog['page']
   self~createTab(9001, p['x'], p['y'], p['w'], p['h'], self~catStyle || " CAT CLIPSIBLINGS")

   if \ self~startParentDialog(0, .false) then return 0

   do i = 1 to self~catalog['count']
      self~catalog['category'] = i

      -- Start the dialog template for this page.  (Ignore an error, an exception will be raised)
      self~createCategoryDialog(p['x']+2, p['y']+(size~height*2), p['w']-10, p['h']-(size~height*3),p['font'], p['fsize'], p['expected'])

      -- Invoke the user defined method with the same name as the page name.  This is where the
      -- dialog control items for this page are defined.
      self~send(self~catalog['names'][i]~space(0))

      -- Create the underlying Windows dialog for this page.
      hChildDlg = self~startChildDialog(self~catalog['base'][i], i)
      self~catalog['base'][i] = 0
      self~catalog['handles'][i] = hChildDlg
   end

   /* This method adds controls to the base window of a 'CategoryDialog' */

::method categoryPage protected
   p = self~catalog['page']
   lbtext = p['leftbtntext']
   rbtext = p['rightbtntext']
   if lbtext~pos(" ") > 0 then lbtext = '"' || lbtext || '"'
   if rbtext~pos(" ") > 0 then rbtext = '"' || rbtext || '"'

   if (p['btnwidth'] > 0) then bw = p['btnwidth']; else bw = 35

   x = trunc(p['w'] + p['x'] + 2 - bw * 2.25)
   y = self~sizeY - 15
   pbTextIdMsg = "&Ok 1 OK &Cancel 2 CANCEL"
   wizardTextIdMsg = lbtext" 11 PreviousPage" rbtext" 12 NextPage"

   self~createPushButtonGroup(x, y, bw, , pbTextIdMsg, 1, "DEFAULT")
   if self~wizard then self~createPushButtonGroup(p['x'] - 2, y, bw, , wizardTextIdMsg, 1, "")


::method initDialog

   tc = self~newTab(9001, 0)
   if tc \= .nil then do
      do i = 1 to self~catalog['count']
         tc~insert(,self~catalog['names'][i])
      end
      tc~selectIndex(0)
   end
   if self~wizard then self~disableItem(11)

   -- call initXXXX for each category, if such a method exists.  The Rect is for
   -- setWindowPos(), where the values are ignored because of NOMOVE / NOSIZE.
   r = .Rect~new
   do i = 1 to self~catalog['count']
      self~catalog['category'] = i
      initMethod = "init" || self~catalog['names'][i]~space(0)
      if self~hasMethod(initMethod) then self~send(initMethod)

      -- This ensures the child dialog is above the tab control and prevents painting
      -- problems when the dialog is covered by another window and then uncovered.
      wnd = .Window~new(self~catalog['handles'][i])
      wnd~setWindowPos(TOP, r, "NOSIZE NOMOVE NOOWNERZORDER")
   end

   /* set the mark to the first radio button */
   self~catalog['category'] = 1
   self~showWindow(self~catalog['handles'][self~catalog['category']])


::method getSelectedPage unguarded
   return self~newTab(9001, 0)~selectedIndex+1


::method changePage unguarded
   use arg newPage

   oldPage = self~catalog['category']
   /* if ChangePage is called automatically then 2 arguments are passed (WParam and LParam) */
   if arg(2,'o') = 0 | newPage > 9000 then newPage = self~getSelectedPage
   else do
      self~newTab(9001, 0)~selectIndex(newPage-1)
   end
   if (newPage = self~catalog['category']) |,
      (newPage < 1 | newPage> self~catalog['count']) then return 0
   self~hideWindowFast(self~catalog['handles'][self~catalog['category']])
   self~catalog['category'] = newPage
   if self~wizard then do
      if newPage = 1 then do
         self~disableItem(11)
         self~enableItem(12)
      end
      else if newPage = self~catalog['count'] then do
         self~enableItem(11)
         self~disableItem(12)
      end
      else do
         self~enableItem(11)
         self~enableItem(12)
      end
   end
   self~showWindow(self~catalog['handles'][self~catalog['category']])

   self~pageHasChanged(oldPage, newPage)
   return newPage


/**
 * Windows Dialog Interface for Open Object Rexx (ooRexx.)
 *
 * ooDialog classes that are more Shell orientated than the original ooDialog
 * implementation.
 *
 * BrowseForFolder     Main 'browse for folder' class, allows customization.
 *
 * SimpleFolderBrowse  Simplified version of BrowseForFolder with ???
 *
 */


::class 'BrowseForFolder' public

::attribute banner get external "LIBRARY oodialog bff_banner"
::attribute banner set external "LIBRARY oodialog bff_setBanner"
::attribute dlgTitle get external "LIBRARY oodialog bff_dlgTitle"
::attribute dlgTitle set external "LIBRARY oodialog bff_setDlgTitle"
::attribute hint get external "LIBRARY oodialog bff_hint"
::attribute hint set external "LIBRARY oodialog bff_setHint"
::attribute initialThread get external "LIBRARY oodialog bff_initialThread"
::attribute options get external "LIBRARY oodialog bff_options"
::attribute options set external "LIBRARY oodialog bff_setOptions"
::attribute owner get external "LIBRARY oodialog bff_Owner"
::attribute owner set external "LIBRARY oodialog bff_setOwner"
::attribute root get external "LIBRARY oodialog bff_root"
::attribute root set external "LIBRARY oodialog bff_setRoot"
::attribute startDir get external "LIBRARY oodialog bff_startDir"
::attribute startDir set external "LIBRARY oodialog bff_setStartDir"
::attribute usePathForHint get external "LIBRARY oodialog bff_usePathForHint"
::attribute usePathForHint set external "LIBRARY oodialog bff_setUsePathForHint"

::method init external "LIBRARY oodialog bff_init"
::method uninit external "LIBRARY oodialog bff_uninit"

::method getDisplayName external "LIBRARY oodialog bff_getDisplayName"
::method getFolder external "LIBRARY oodialog bff_getFolder"
::method getItemIDList external "LIBRARY oodialog bff_getItemIDList"
::method initCOM external "LIBRARY oodialog bff_initCOM"
::method releaseCOM external "LIBRARY oodialog bff_releaseCOM"
::method releaseItemIDList external "LIBRARY oodialog bff_releaseItemIDList"
::method test external "LIBRARY oodialog bff_test"


::class 'CommonItemDialog' public inherit ComConstants

::attribute options get external "LIBRARY oodialog cid_options"
::attribute options set external "LIBRARY oodialog cid_setOptions"

::method init external "LIBRARY oodialog cid_init"
::method uninit external "LIBRARY oodialog cid_uninit"

::method addPlace external "LIBRARY oodialog cid_addPlace"
::method advise external "LIBRARY oodialog cid_advise"
::method clearClientData external "LIBRARY oodialog cid_clearClientData"
::method close unguarded external "LIBRARY oodialog cid_close"
::method getCurrentSelection unguarded external "LIBRARY oodialog cid_getCurrentSelection"
::method getFileName unguarded external "LIBRARY oodialog cid_getFileName"
::method getFileTypeIndex unguarded external "LIBRARY oodialog cid_getFileTypeIndex"
::method getFolder external "LIBRARY oodialog cid_getFolder"
::method getResult external "LIBRARY oodialog cid_getResult"
::method initCOM unguarded external "LIBRARY oodialog cid_initCOM"
::method isReleased unguarded external "LIBRARY oodialog cid_isReleased"
::method release external "LIBRARY oodialog cid_release"
::method releaseCOM unguarded external "LIBRARY oodialog cid_releaseCOM"
::method setClientGuid external "LIBRARY oodialog cid_setClientGuid"
::method setDefaultExtension external "LIBRARY oodialog cid_setDefaultExtension"
::method setDefaultFolder external "LIBRARY oodialog cid_setDefaultFolder"
::method setFileName external "LIBRARY oodialog cid_setFileName"
::method setFileNameLabel external "LIBRARY oodialog cid_setFileNameLabel"
::method setFileTypeIndex external "LIBRARY oodialog cid_setFileTypeIndex"
::method setFileTypes external "LIBRARY oodialog cid_setFileTypes"
::method setFilter external "LIBRARY oodialog cid_setFilter"
::method setFolder external "LIBRARY oodialog cid_setFolder"
::method setCancelButtonLabel external "LIBRARY oodialog cid_setCancelButtonLabel"
::method setOkButtonLabel external "LIBRARY oodialog cid_setOkButtonLabel"
::method setTitle external "LIBRARY oodialog cid_setTitle"
::method show unguarded external "LIBRARY oodialog cid_show"
::method unadvise unguarded external "LIBRARY oodialog cid_unadvise"


::class 'OpenFileDialog' public subclass CommonItemDialog
::method init external "LIBRARY oodialog ofd_init"
::method getResults external "LIBRARY oodialog ofd_getResults"


::class 'SaveFileDialog' public subclass CommonItemDialog
::method init external "LIBRARY oodialog sfd_init"
::method setSaveAsItem external "LIBRARY oodialog sfd_setSaveAsItem"


::class 'CommonDialogCustomizations' public mixinclass Object
::method initCustomizations private external "LIBRARY oodialog cid_initCustomizations"  -- Internal use only
::method addCheckButton external "LIBRARY oodialog cid_addCheckButton"
::method addComboBox external "LIBRARY oodialog cid_addComboBox"
::method addControlItem external "LIBRARY oodialog cid_addControlItem"
::method addEditBox external "LIBRARY oodialog cid_addEditBox"
::method addMenu external "LIBRARY oodialog cid_addMenu"
::method addPushButton external "LIBRARY oodialog cid_addPushButton"
::method addRadioButtonList external "LIBRARY oodialog cid_addRadioButtonList"
::method addSeparator external "LIBRARY oodialog cid_addSeparator"
::method addText external "LIBRARY oodialog cid_addText"
::method check external "LIBRARY oodialog cid_setCheckButtonState"
::method enableOpenDropDown external "LIBRARY oodialog cid_enableOpenDropDown"
::method endVisualGroup external "LIBRARY oodialog cid_endVisualGroup"
::method getCheckButtonState external "LIBRARY oodialog cid_getCheckButtonState"
::method getControlItemState external "LIBRARY oodialog cid_getControlItemState"
::method getControlState external "LIBRARY oodialog cid_getControlState"
::method getEditBoxText external "LIBRARY oodialog cid_getEditBoxText"
::method getSelectedControlItem external "LIBRARY oodialog cid_getSelectedControlItem"
::method isChecked external "LIBRARY oodialog cid_getCheckButtonState"
::method makeProminent external "LIBRARY oodialog cid_makeProminent"
::method removeAllControlItems external "LIBRARY oodialog cid_removeAllControlItems"
::method removeControlItem external "LIBRARY oodialog cid_removeControlItem"
::method setCheckButtonState external "LIBRARY oodialog cid_setCheckButtonState"
::method setControlItemState external "LIBRARY oodialog cid_setControlItemState"
::method setControlItemText external "LIBRARY oodialog cid_setControlItemText"
::method setControlLabel external "LIBRARY oodialog cid_setControlLabel"
::method setControlState external "LIBRARY oodialog cid_setControlState"
::method setEditBoxText external "LIBRARY oodialog cid_setEditBoxText"
::method setSelectedControlItem external "LIBRARY oodialog cid_setSelectedControlItem"
::method startVisualGroup external "LIBRARY oodialog cid_startVisualGroup"
::method uncheck external "LIBRARY oodialog cid_setCheckButtonState"

::class 'ComConstants' mixinclass Object
::constant  CANCELED          2147943623
::constant  E_NOTIMPL         34360000513  -- _HRESULT_TYPEDEF_(0x80004001L)
::constant  S_FALSE           1
::constant  S_OK              0


::class 'ShellItemFilter' public inherit ComConstants
::method init external "LIBRARY oodialog sif_init"
::method includeItem unguarded
    return self~S_OK


::class 'CommonDialogEvents' public inherit ComConstants

-- OnOverwrite and OnShareViolation response constants
::constant  FDESVR_DEFAULT    0
::constant  FDESVR_ACCEPT     1
::constant  FDESVR_REFUSE     2


::method init external "LIBRARY oodialog cde_init"
::method onButtonClicked unguarded
    return self~S_OK

::method onCheckButtonToggled unguarded
    return self~S_OK

::method onControlActivating unguarded
    return self~S_OK

::method onFileOk unguarded
    return self~S_OK

::method onFolderChange unguarded
    return self~S_OK

::method onFolderChanging unguarded
    return self~S_OK

::method onHelp unguarded
    return self~S_OK

::method onItemSelected unguarded
    return self~S_OK

::method onOverwrite unguarded
    return self~FDESVR_DEFAULT

::method onSelectionChange unguarded
    return self~S_OK

::method onShareViolation unguarded
    return self~FDESVR_DEFAULT

::method onTypeChange unguarded
    return self~S_OK


::class 'SimpleFolderBrowse' public
::method getFolder class external "LIBRARY oodialog sfb_getFolder"

