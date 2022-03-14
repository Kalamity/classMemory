/*
    A basic memory class by RHCP:

    This is a wrapper for commonly used read and write memory functions.
    It also contains a variety of pattern scan functions.
    This class allows scripts to read/write integers and strings of various types. 
    Pointer addresses can easily be read/written by passing the base address and offsets to the various read/write functions.
    
    Process handles are kept open between reads. This increases speed.
    However, if a program closes/restarts then the process handle will become invalid
    and you will need to re-open another handle (blank/destroy the object and recreate it)
    isHandleValid() can be used to check if a handle is still active/valid.

    read(), readString(), write(), and writeString() can be used to read and write memory addresses respectively.

    readRaw() can be used to dump large chunks of memory, this is considerably faster when
    reading data from a large structure compared to repeated calls to read(). 
    For example, reading a single UInt takes approximately the same amount of time as reading 1000 bytes via readRaw().
    Although, most people wouldn't notice the performance difference. This does however require you 
    to retrieve the values using AHK's numget()/strGet() from the dumped memory.

    In a similar fashion writeRaw() allows a buffer to be be written in a single operation. 
    
    When the new operator is used this class returns an object which can be used to read that process's 
    memory space.To read another process simply create another object.

    Process handles are automatically closed when the script exits/restarts or when you free the object.

    **Notes:
        This was initially written for 32 bit target processes, however the various read/write functions
        should now completely support pointers in 64 bit target applications. The only caveat is that the AHK exe must also be 64 bit.  
        If AHK is 32 bit and the target application is 64 bit you can still read, write, and use pointers, so long as the addresses
        fit inside a 4 byte pointer, i.e. The maximum address is limited to the 32 bit range.

        The various pattern scan functions are intended to be used on 32 bit target applications, however: 
            - A 32 bit AHK script can perform pattern scans on a 32 bit target application.
            - A 32 bit AHK script may be able to perform pattern scans on a 64 bit process, providing the addresses fall within the 32 bit range.             
            - A 64 bit AHK script should be able to perform pattern scans on a 32 or 64 bit target application without issue. 

        If the target process has admin privileges, then the AHK script will also require admin privileges. 

        AHK doesn't support unsigned 64bit ints, you can however read them as Int64 and interpret negative values as large numbers.       
  

    Commonly used methods:
        read()
        readString()
        readRaw()
        write()
        writeString()
        writeBytes()
        writeRaw()
        isHandleValid() 
        getModuleBaseAddress()
        GetDllBaseAddress()
        VirtualAllocEx()
        VirtualFreeEx()
        CreateRemoteThread()

    Less commonly used methods:
        getProcessBaseAddress()
        
        hexStringToPattern()
        stringToPattern()    
        modulePatternScan()
        processPatternScan()
        addressPatternScan()
        rawPatternScan()
        getModules()
        numberOfBytesRead()
        numberOfBytesWritten()
        suspend()
        resume()

    Internal methods: (some may be useful when directly called)
        getAddressFromOffsets() ; This will return the final memory address of a pointer. This is useful if the pointed address only changes on startup or map/level change and you want to eliminate the overhead associated with pointers.
        isTargetProcess64Bit()
        pointer() 
        GetModuleFileNameEx()
        EnumProcessModulesEx()
        GetModuleInformation()
        getNeedleFromAOBPattern()
        virtualQueryEx()
        patternScan()
        bufferScanForMaskedPattern()
        openProcess()
        closeHandle() 

    Useful properties:  (Do not modify the values of these properties - they are set automatically)
        baseAddress             ; The base address of the target process
        hProcess                ; The handle to the target process
        PID                     ; The PID of the target process
        currentProgram          ; The string the user used to identify the target process e.g. "ahk_exe calc.exe" 
        isTarget64bit           ; True if target process is 64 bit, otherwise false
        readStringLastError     ; Used to check for success/failure when reading a string

     Useful editable properties:
        insertNullTerminator    ; Determines if a null terminator is inserted when writing strings.
               

    Usage:

        ; **Note: If you wish to try this calc example, consider using the 32 bit version of calc.exe - 
        ;         which is in C:\Windows\SysWOW64\calc.exe on win7 64 bit systems.

        ; The contents of this file can be copied directly into your script. Alternately, you can copy the classMemory.ahk file into your library folder,
        ; in which case you will need to use the #include directive in your script i.e. 
            #Include <classMemory>
        
        ; You can use this code to check if you have installed the class correctly.
            if (_ClassMemory.__Class != "_ClassMemory")
            {
                msgbox class memory not correctly installed. Or the (global class) variable "_ClassMemory" has been overwritten
                ExitApp
            }

        ; Open a process with sufficient access to read and write memory addresses (this is required before you can use the other functions)
        ; You only need to do this once. But if the process closes/restarts, then you will need to perform this step again. Refer to the notes section below.
        ; Also, if the target process is running as admin, then the script will also require admin rights!
        ; Note: The program identifier can be any AHK windowTitle i.e.ahk_exe, ahk_class, ahk_pid, or simply the window title.
        ; hProcessCopy is an optional variable in which the opened handled is stored. 
          
            calc := new _ClassMemory("ahk_exe calc.exe", "", hProcessCopy) 
       
        ; Check if the above method was successful.
            if !isObject(calc) 
            {
                msgbox failed to open a handle
                if (hProcessCopy = 0)
                    msgbox The program isn't running (not found) or you passed an incorrect program identifier parameter. In some cases _ClassMemory.setSeDebugPrivilege() may be required. 
                else if (hProcessCopy = "")
                    msgbox OpenProcess failed. If the target process has admin rights, then the script also needs to be ran as admin. _ClassMemory.setSeDebugPrivilege() may also be required. Consult A_LastError for more information.
                ExitApp
            }

        ; Get the process's base address.
        ; When using the new operator this property is automatically set to the result of getModuleBaseAddress() or getProcessBaseAddress();
        ; the specific method used depends on the bitness of the target application and AHK.
        ; If the returned address is incorrect and the target application is 64 bit, but AHK is 32 bit, try using the 64 bit version of AHK.
            msgbox % calc.BaseAddress 
        
        ; Get the base address of a specific module.
            msgbox % calc.getModuleBaseAddress("GDI32.dll")

        ; The rest of these examples are just for illustration (the addresses specified are probably not valid).
        ; You can use cheat engine to find real addresses to read and write for testing purposes.
        
        ; Write 1234 as a UInt at address 0x0016CB60.
            calc.write(0x0016CB60, 1234, "UInt")

        ; Read a UInt.
            value := calc.read(0x0016CB60, "UInt")

        ; Read a pointer with offsets 0x20 and 0x15C which points to a UChar. 
            value := calc.read(pointerBase, "UChar", 0x20, 0x15C)

        ; Note: read(), readString(), readRaw(), write(), writeString(), and writeRaw() all support pointers/offsets.
        ; An array of pointers can be passed directly, i.e.
            arrayPointerOffsets := [0x20, 0x15C]
            value := calc.read(pointerBase, "UChar", arrayPointerOffsets*)
        ; Or they can be entered manually.
            value := calc.read(pointerBase, "UChar", 0x20, 0x15C)
        ; You can also pass all the parameters directly, i.e.
            aMyPointer := [pointerBase, "UChar", 0x20, 0x15C]
            value := calc.read(aMyPointer*)

        
        ; Read a utf-16 null terminated string of unknown size at address 0x1234556 - the function will read until the null terminator is found or something goes wrong.
            string := calc.readString(0x1234556, length := 0, encoding := "utf-16")
        
        ; Read a utf-8 encoded string which is 12 bytes long at address 0x1234556.
            string := calc.readString(0x1234556, 12)

        ; By default a null terminator is included at the end of written strings for writeString().
        ; The nullterminator property can be used to change this.
            _ClassMemory.insertNullTerminator := False ; This will change the property for all processes
            calc.insertNullTerminator := False ; Changes the property for just this process     


    Notes: 
        If the target process exits and then starts again (or restarts) you will need to free the derived object and then use the new operator to create a new object i.e. 
        calc := [] ; or calc := "" ; free the object. This is actually optional if using the line below, as the line below would free the previous derived object calc prior to initialising the new copy.
        calc := new _ClassMemory("ahk_exe calc.exe") ; Create a new derived object to read calc's memory.
        isHandleValid() can be used to check if a target process has closed or restarted.
*/

class _ClassMemory
{
    ; List of useful accessible values. Some of these inherited values (the non objects) are set when the new operator is used.
    static baseAddress, hProcess, PID, currentProgram
    , insertNullTerminator := True
    , readStringLastError := False
    , isTarget64bit := False
    , ptrType := "UInt"
    , aTypeSize := {    "UChar":    1,  "Char":     1
                    ,   "UShort":   2,  "Short":    2
                    ,   "UInt":     4,  "Int":      4
                    ,   "UFloat":   4,  "Float":    4
                    ,   "Int64":    8,  "Double":   8}  
    , aRights := {  "PROCESS_ALL_ACCESS": 0x001F0FFF
                ,   "PROCESS_CREATE_PROCESS": 0x0080
                ,   "PROCESS_CREATE_THREAD": 0x0002
                ,   "PROCESS_DUP_HANDLE": 0x0040
                ,   "PROCESS_QUERY_INFORMATION": 0x0400
                ,   "PROCESS_QUERY_LIMITED_INFORMATION": 0x1000
                ,   "PROCESS_SET_INFORMATION": 0x0200
                ,   "PROCESS_SET_QUOTA": 0x0100
                ,   "PROCESS_SUSPEND_RESUME": 0x0800
                ,   "PROCESS_TERMINATE": 0x0001
                ,   "PROCESS_VM_OPERATION": 0x0008
                ,   "PROCESS_VM_READ": 0x0010
                ,   "PROCESS_VM_WRITE": 0x0020
                ,   "SYNCHRONIZE": 0x00100000}


    ; Method:    __new(program, dwDesiredAccess := "", byRef handle := "", windowMatchMode := 3)
    ; Example:  derivedObject := new _ClassMemory("ahk_exe calc.exe")
    ;           This is the first method which should be called when trying to access a program's memory. 
    ;           If the process is successfully opened, an object is returned which can be used to read that processes memory space.
    ;           [derivedObject].hProcess stores the opened handle.
    ;           If the target process closes and re-opens, simply free the derived object and use the new operator again to open a new handle.
    ; Parameters:
    ;   program             The program to be opened. This can be any AHK windowTitle identifier, such as 
    ;                       ahk_exe, ahk_class, ahk_pid, or simply the window title. e.g. "ahk_exe calc.exe" or "Calculator".
    ;                       It's safer not to use the window title, as some things can have the same window title e.g. an open folder called "Starcraft II"
    ;                       would have the same window title as the game itself.
    ;                       *'DetectHiddenWindows, On' is required for hidden windows*
    ;   dwDesiredAccess     The access rights requested when opening the process.
    ;                       If this parameter is null the process will be opened with the following rights
    ;                       PROCESS_QUERY_INFORMATION, PROCESS_VM_OPERATION, PROCESS_VM_READ, PROCESS_VM_WRITE, & SYNCHRONIZE
    ;                       This access level is sufficient to allow all of the methods in this class to work.
    ;                       Specific process access rights are listed here http://msdn.microsoft.com/en-us/library/windows/desktop/ms684880(v=vs.85).aspx                           
    ;   handle (Output)     Optional variable in which a copy of the opened processes handle will be stored.
    ;                       Values:
    ;                           Null    OpenProcess failed. The script may need to be run with admin rights admin, 
    ;                                   and/or with the use of _ClassMemory.setSeDebugPrivilege(). Consult A_LastError for more information.
    ;                           0       The program isn't running (not found) or you passed an incorrect program identifier parameter.
    ;                                   In some cases _ClassMemory.setSeDebugPrivilege() may be required.
    ;                           Positive Integer    A handle to the process. (Success)
    ;   windowMatchMode -   Determines the matching mode used when finding the program (windowTitle).
    ;                       The default value is 3 i.e. an exact match. Refer to AHK's setTitleMathMode for more information.
    ; Return Values: 
    ;   Object  On success an object is returned which can be used to read the processes memory.
    ;   Null    Failure. A_LastError and the optional handle parameter can be consulted for more information. 


    __new(program, dwDesiredAccess := "", byRef handle := "", windowMatchMode := 3)
    {         
        if this.PID := handle := this.findPID(program, windowMatchMode) ; set handle to 0 if program not found
        {
            ; This default access level is sufficient to read and write memory addresses, and to perform pattern scans.
            ; if the program is run using admin privileges, then this script will also need admin privileges
            if dwDesiredAccess is not integer       
                dwDesiredAccess := this.aRights.PROCESS_QUERY_INFORMATION | this.aRights.PROCESS_VM_OPERATION | this.aRights.PROCESS_VM_READ | this.aRights.PROCESS_VM_WRITE
            dwDesiredAccess |= this.aRights.SYNCHRONIZE ; add SYNCHRONIZE to all handles to allow isHandleValid() to work

            if this.hProcess := handle := this.OpenProcess(this.PID, dwDesiredAccess) ; NULL/Blank if failed to open process for some reason
            {
                this.pNumberOfBytesRead := DllCall("GlobalAlloc", "UInt", 0x0040, "Ptr", A_PtrSize, "Ptr") ; 0x0040 initialise to 0
                this.pNumberOfBytesWritten := DllCall("GlobalAlloc", "UInt", 0x0040, "Ptr", A_PtrSize, "Ptr") ; initialise to 0

                this.readStringLastError := False
                this.currentProgram := program
                if this.isTarget64bit := this.isTargetProcess64Bit(this.PID, this.hProcess, dwDesiredAccess)
                    this.ptrType := "Int64"
                else this.ptrType := "UInt" ; If false or Null (fails) assume 32bit
                
                ; if script is 64 bit, getModuleBaseAddress() should always work
                ; if target app is truly 32 bit, then getModuleBaseAddress()
                ; will work when script is 32 bit
                if (A_PtrSize != 4 || !this.isTarget64bit)
                    this.BaseAddress := this.getModuleBaseAddress()

                ; If the above failed or wasn't called, fall back to alternate method    
                if this.BaseAddress < 0 || !this.BaseAddress
                    this.BaseAddress := this.getProcessBaseAddress(program, windowMatchMode)            

                return this
            }
        }
        return
    }

    __delete()
    {
        this.closeHandle(this.hProcess)
        if this.pNumberOfBytesRead
            DllCall("GlobalFree", "Ptr", this.pNumberOfBytesRead)
        if this.pNumberOfBytesWritten
            DllCall("GlobalFree", "Ptr", this.pNumberOfBytesWritten)
        return
    }

    ; Method: CreateRemoteThread(pRemoteAddress)
    ; parameters:
    ;   pRemoteAddress - The address of the function to be executed.

    CreateRemoteThread(pRemoteAddress)
    {
        return DllCall("CreateRemoteThread", "Ptr", this.hProcess, "Ptr", 0, "Ptr", 0, "Ptr", pRemoteAddress, "Ptr", 0, "Ptr", 0, "Ptr", 0)
    }
    
    ; Method: VirtualAllocEx(pSize)
    ; parameters:
    ;   pSize    The size of the memory allocation.

    VirtualAllocEx(pSize)
    {
        return DllCall("VirtualAllocEx", "Ptr", this.hProcess, "Ptr", 0, "Ptr", pSize, "Ptr", 0x1000, "Ptr", 0x40)
    }

    ; Method:    VirtualFreeEx(pAddress, pSize)
    ; parameters:
    ;   pAddress    The address of the memory to be freed.
    ;   pSize       The size of the memory to be freed.

    VirtualFreeEx(pAddress, pSize)
    {
        return DllCall("VirtualFreeEx", "Ptr", this.hProcess, "Ptr", pAddress, "Ptr", pSize, "Ptr", 0x4000)
    }

    version()
    {
        return 2.92
    }   

    findPID(program, windowMatchMode := "3", num := -1)
    {
        ; If user passes an AHK_PID, don't bother searching. There are cases where searching windows for PIDs 
        ; wont work - console apps
        if RegExMatch(program, "i)\s*AHK_PID\s+(0x[[:xdigit:]]+|\d+)", pid)
            return pid1
        if windowMatchMode
        {
            ; This is a string and will not contain the 0x prefix
            mode := A_TitleMatchMode
            ; remove hex prefix as SetTitleMatchMode will throw a run time error. This will occur if integer mode is set to hex and user passed an int (unquoted)
            StringReplace, windowMatchMode, windowMatchMode, 0x 
            SetTitleMatchMode, %windowMatchMode%
        }
        WinGet, pid, pid, %program%
        if windowMatchMode
            SetTitleMatchMode, %mode%    ; In case executed in autoexec

        ; If use 'ahk_exe test.exe' and winget fails (which can happen when setSeDebugPrivilege is required),
        ; try using the process command. When it fails due to setSeDebugPrivilege, setSeDebugPrivilege will still be required to openProcess
        ; This should also work for apps without windows.
        if (!pid && RegExMatch(program, "i)\bAHK_EXE\b\s*(.*)", fileName))
        {
            ; remove any trailing AHK_XXX arguments
            filename := RegExReplace(filename1, "i)\bahk_(class|id|pid|group)\b.*", "")
            filename := trim(filename)    ; extra spaces will make process command fail       
            ; AHK_EXE can be the full path, so just get filename
            SplitPath, fileName , fileName
            if (fileName) ; if filename blank, scripts own pid is returned
            {
                arid:=[]
                len:=0
                s := VarSetCapacity(a, 4096)  ; An array that receives the list of process identifiers:
                DllCall("Psapi.dllEnumProcesses", "Ptr", &a, "UInt", s, "UIntP", r)
                Loop, % r // 4  ; Parse array for identifiers as DWORDs (32 bits):
                {
                   id := NumGet(a, A_Index * 4, "UInt")
                   if h := DllCall("OpenProcess", "UInt", 0x0410, "Int", false, "UInt", id, "Ptr")
                   {
                      VarSetCapacity(name, s, 0)  ; a buffer that receives the base name of the module:
                      DllCall("Psapi.dllGetModuleBaseName", "Ptr", h, "Ptr", 0, "Str", name, "UInt", A_IsUnicode ? s//2 : s)
                      DllCall("CloseHandle", "Ptr", h)  ; close process handle to save memory
                      if (name=fileName){
                        hProc := DllCall("OpenProcess", "Ptr", 0x400, "Ptr", 0, "Ptr", id)
                        DllCall("kernel32GetProcessTimes", "Ptr",hProc, "Int64*",vIntervalsUTC, "Ptr",0, "Ptr",0, "Ptr",0)
                        DllCall("CloseHandle", "Ptr", hProc)  ; close process handle to save memory
                        arid[vIntervalsUTC]:=id
                        len+=1
                    }
                   }
                }
                DllCall("FreeLibrary", "Ptr", hModule)  ; Unload the library to free memory.
                c := (num < 0? len + mod(num, len) : mod(num - 1, len)) + 1
                for k, v in arid
                    if (A_Index = c)
                        return v
            }
        }

        return pid ? pid : 0 ; PID is null on fail, return 0
    }
    ; Method:   isHandleValid()
    ;           This method provides a means to check if the internal process handle is still valid
    ;           or in other words, the specific target application instance (which you have been reading from)
    ;           has closed or restarted.
    ;           For example, if the target application closes or restarts the handle will become invalid
    ;           and subsequent calls to this method will return false.
    ;
    ; Return Values: 
    ;   True    The handle is valid.
    ;   False   The handle is not valid. 
    ;
    ; Notes: 
    ;   This operation requires a handle with SYNCHRONIZE access rights.
    ;   All handles, even user specified ones are opened with the SYNCHRONIZE access right.

    isHandleValid()
    {
        return 0x102 = DllCall("WaitForSingleObject", "Ptr", this.hProcess, "UInt", 0)
        ; WaitForSingleObject return values
        ; -1 if called with null hProcess (sets lastError to 6 - invalid handle)
        ; 258 / 0x102 WAIT_TIMEOUT - if handle is valid (process still running)
        ; 0  WAIT_OBJECT_0 - if process has terminated        
    }

    ; Method:   openProcess(PID, dwDesiredAccess)
    ;           ***Note:    This is an internal method which shouldn't be called directly unless you absolutely know what you are doing.
    ;                       This is because the new operator, in addition to calling this method also sets other values
    ;                       which are required for the other methods to work correctly. 
    ; Parameters:
    ;   PID                 The Process ID of the target process.  
    ;   dwDesiredAccess     The access rights requested when opening the process.
    ;                       Specific process access rights are listed here http://msdn.microsoft.com/en-us/library/windows/desktop/ms684880(v=vs.85).aspx                           
    ; Return Values: 
    ;   Null/blank          OpenProcess failed. If the target process has admin rights, then the script also needs to be ran as admin. 
    ;                       _ClassMemory.setSeDebugPrivilege() may also be required.
    ;   Positive integer    A handle to the process.

    openProcess(PID, dwDesiredAccess)
    {
        r := DllCall("OpenProcess", "UInt", dwDesiredAccess, "Int", False, "UInt", PID, "Ptr")
        ; if it fails with 0x5 ERROR_ACCESS_DENIED, try enabling privilege ... lots of users never try this.
        ; there may be other errors which also require DebugPrivilege....
        if (!r && A_LastError = 5)
        {
            this.setSeDebugPrivilege(true) ; no harm in enabling it if it is already enabled by user
            if (r2 := DllCall("OpenProcess", "UInt", dwDesiredAccess, "Int", False, "UInt", PID, "Ptr"))
                return r2
            DllCall("SetLastError", "UInt", 5) ; restore original error if it doesnt work
        }
        ; If fails with 0x5 ERROR_ACCESS_DENIED (when setSeDebugPrivilege() is req.), the func. returns 0 rather than null!! Set it to null.
        ; If fails for another reason, then it is null.
        return r ? r : ""
    }   

    ; Method:   closeHandle(hProcess)
    ;           Note:   This is an internal method which is automatically called when the script exits or the derived object is freed/destroyed.
    ;                   There is no need to call this method directly. If you wish to close the handle simply free the derived object. 
    ;                   i.e. derivedObject := [] ; or derivedObject := ""
    ; Parameters:
    ;   hProcess        The handle to the process, as returned by openProcess().
    ; Return Values: 
    ;   Non-Zero        Success
    ;   0               Failure

    closeHandle(hProcess)
    {
        return DllCall("CloseHandle", "Ptr", hProcess)
    }

    ; Methods:      numberOfBytesRead() / numberOfBytesWritten()
    ;               Returns the number of bytes read or written by the last ReadProcessMemory or WriteProcessMemory operation. 
    ;             
    ; Return Values: 
    ;   zero or positive value      Number of bytes read/written
    ;   -1                          Failure. Shouldn't occur 

    numberOfBytesRead()
    {
        return !this.pNumberOfBytesRead ? -1 : NumGet(this.pNumberOfBytesRead+0, "Ptr")
    }
    numberOfBytesWritten()
    {
        return !this.pNumberOfBytesWritten ? -1 : NumGet(this.pNumberOfBytesWritten+0, "Ptr")
    }


    ; Method:   read(address, type := "UInt", aOffsets*)
    ;           Reads various integer type values
    ; Parameters:
    ;       address -   The memory address of the value or if using the offset parameter, 
    ;                   the base address of the pointer.
    ;       type    -   The integer type. 
    ;                   Valid types are UChar, Char, UShort, Short, UInt, Int, Float, Int64 and Double. 
    ;                   Note: Types must not contain spaces i.e. " UInt" or "UInt " will not work. 
    ;                   When an invalid type is passed the method returns NULL and sets ErrorLevel to -2
    ;       aOffsets* - A variadic list of offsets. When using offsets the address parameter should equal the base address of the pointer.
    ;                   The address (base address) and offsets should point to the memory address which holds the integer.  
    ; Return Values:
    ;       integer -   Indicates success.
    ;       Null    -   Indicates failure. Check ErrorLevel and A_LastError for more information.
    ;       Note:       Since the returned integer value may be 0, to check for success/failure compare the result
    ;                   against null i.e. if (result = "") then an error has occurred.
    ;                   When reading doubles, adjusting "SetFormat, float, totalWidth.DecimalPlaces"
    ;                   may be required depending on your requirements.

    read(address, type := "UInt", aOffsets*)
    {
        ; If invalid type RPM() returns success (as bytes to read resolves to null in dllCall())
        ; so set errorlevel to invalid parameter for DLLCall() i.e. -2
        if !this.aTypeSize.hasKey(type)
            return "", ErrorLevel := -2 
        if DllCall("ReadProcessMemory", "Ptr", this.hProcess, "Ptr", aOffsets.maxIndex() ? this.getAddressFromOffsets(address, aOffsets*) : address, type "*", result, "Ptr", this.aTypeSize[type], "Ptr", this.pNumberOfBytesRead)
            return result
        return        
    }

    ; Method:   readRaw(address, byRef buffer, bytes := 4, aOffsets*)
    ;           Reads an area of the processes memory and stores it in the buffer variable
    ; Parameters:
    ;       address  -  The memory address of the area to read or if using the offsets parameter
    ;                   the base address of the pointer which points to the memory region.
    ;       buffer   -  The unquoted variable name for the buffer. This variable will receive the contents from the address space.
    ;                   This method calls varsetCapcity() to ensure the variable has an adequate size to perform the operation. 
    ;                   If the variable already has a larger capacity (from a previous call to varsetcapcity()), then it will not be shrunk. 
    ;                   Therefore it is the callers responsibility to ensure that any subsequent actions performed on the buffer variable
    ;                   do not exceed the bytes which have been read - as these remaining bytes could contain anything.
    ;       bytes   -   The number of bytes to be read.          
    ;       aOffsets* - A variadic list of offsets. When using offsets the address parameter should equal the base address of the pointer.
    ;                   The address (base address) and offsets should point to the memory address which is to be read
    ; Return Values:
    ;       Non Zero -   Indicates success.
    ;       Zero     -   Indicates failure. Check errorLevel and A_LastError for more information
    ; 
    ; Notes:            The contents of the buffer may then be retrieved using AHK's NumGet() and StrGet() functions.           
    ;                   This method offers significant (~30% and up) performance boost when reading large areas of memory. 
    ;                   As calling ReadProcessMemory for four bytes takes a similar amount of time as it does for 1,000 bytes.                

    readRaw(address, byRef buffer, bytes := 4, aOffsets*)
    {
        VarSetCapacity(buffer, bytes)
        return DllCall("ReadProcessMemory", "Ptr", this.hProcess, "Ptr", aOffsets.maxIndex() ? this.getAddressFromOffsets(address, aOffsets*) : address, "Ptr", &buffer, "Ptr", bytes, "Ptr", this.pNumberOfBytesRead)
    }

    ; Method:   readString(address, sizeBytes := 0, encoding := "utf-8", aOffsets*)
    ;           Reads string values of various encoding types
    ; Parameters:
    ;       address -   The memory address of the value or if using the offset parameter, 
    ;                   the base address of the pointer.
    ;       sizeBytes - The size (in bytes) of the string to be read.
    ;                   If zero is passed, then the function will read each character until a null terminator is found
    ;                   and then returns the entire string.
    ;       encoding -  This refers to how the string is stored in the program's memory.
    ;                   UTF-8 and UTF-16 are common. Refer to the AHK manual for other encoding types.
    ;       aOffsets* - A variadic list of offsets. When using offsets the address parameter should equal the base address of the pointer.
    ;                   The address (base address) and offsets should point to the memory address which holds the string.                             
    ;                   
    ;  Return Values:
    ;       String -    On failure an empty (null) string is always returned. Since it's possible for the actual string 
    ;                   being read to be null (empty), then a null return value should not be used to determine failure of the method.
    ;                   Instead the property [derivedObject].ReadStringLastError can be used to check for success/failure.
    ;                   This property is set to 0 on success and 1 on failure. On failure ErrorLevel and A_LastError should be consulted
    ;                   for more information.
    ; Notes:
    ;       For best performance use the sizeBytes parameter to specify the exact size of the string. 
    ;       If the exact size is not known and the string is null terminated, then specifying the maximum
    ;       possible size of the string will yield the same performance.  
    ;       If neither the actual or maximum size is known and the string is null terminated, then specifying
    ;       zero for the sizeBytes parameter is fine. Generally speaking for all intents and purposes the performance difference is
    ;       inconsequential.  

    readString(address, sizeBytes := 0, encoding := "UTF-8", aOffsets*)
    {
        bufferSize := VarSetCapacity(buffer, sizeBytes ? sizeBytes : 100, 0)
        this.ReadStringLastError := False
        if aOffsets.maxIndex()
            address := this.getAddressFromOffsets(address, aOffsets*)
        if !sizeBytes  ; read until null terminator is found or something goes wrong
        {
            ; Even if there are multi-byte-characters (bigger than the encodingSize i.e. surrogates) in the string, when reading in encodingSize byte chunks they will never register as null (as they will have bits set on those bytes)
            if (encoding = "utf-16" || encoding = "cp1200")
                encodingSize := 2, charType := "UShort", loopCount := 2
            else encodingSize := 1, charType := "Char", loopCount := 4
            Loop
            {   ; Lets save a few reads by reading in 4 byte chunks
                if !DllCall("ReadProcessMemory", "Ptr", this.hProcess, "Ptr", address + ((outterIndex := A_index) - 1) * 4, "Ptr", &buffer, "Ptr", 4, "Ptr", this.pNumberOfBytesRead) || ErrorLevel
                    return "", this.ReadStringLastError := True 
                else loop, %loopCount%
                {
                    if NumGet(buffer, (A_Index - 1) * encodingSize, charType) = 0 ; NULL terminator
                    {
                        if (bufferSize < sizeBytes := outterIndex * 4 - (4 - A_Index * encodingSize)) 
                            VarSetCapacity(buffer, sizeBytes)
                        break, 2
                    }  
                } 
            }
        }
        if DllCall("ReadProcessMemory", "Ptr", this.hProcess, "Ptr", address, "Ptr", &buffer, "Ptr", sizeBytes, "Ptr", this.pNumberOfBytesRead)   
            return StrGet(&buffer,, encoding)  
        return "", this.ReadStringLastError := True             
    }

    ; Method:  writeString(address, string, encoding := "utf-8", aOffsets*)
    ;          Encodes and then writes a string to the process.
    ; Parameters:
    ;       address -   The memory address to which data will be written or if using the offset parameter, 
    ;                   the base address of the pointer.
    ;       string -    The string to be written.
    ;       encoding -  This refers to how the string is to be stored in the program's memory.
    ;                   UTF-8 and UTF-16 are common. Refer to the AHK manual for other encoding types.
    ;       aOffsets* - A variadic list of offsets. When using offsets the address parameter should equal the base address of the pointer.
    ;                   The address (base address) and offsets should point to the memory address which is to be written to.
    ; Return Values:
    ;       Non Zero -   Indicates success.
    ;       Zero     -   Indicates failure. Check errorLevel and A_LastError for more information
    ; Notes:
    ;       By default a null terminator is included at the end of written strings. 
    ;       This behaviour is determined by the property [derivedObject].insertNullTerminator
    ;       If this property is true, then a null terminator will be included.       

    writeString(address, string, encoding := "utf-8", aOffsets*)
    {
        encodingSize := (encoding = "utf-16" || encoding = "cp1200") ? 2 : 1
        requiredSize := StrPut(string, encoding) * encodingSize - (this.insertNullTerminator ? 0 : encodingSize)
        VarSetCapacity(buffer, requiredSize)
        StrPut(string, &buffer, StrLen(string) + (this.insertNullTerminator ?  1 : 0), encoding)
        return DllCall("WriteProcessMemory", "Ptr", this.hProcess, "Ptr", aOffsets.maxIndex() ? this.getAddressFromOffsets(address, aOffsets*) : address, "Ptr", &buffer, "Ptr", requiredSize, "Ptr", this.pNumberOfBytesWritten)
    }
    
    ; Method:   write(address, value, type := "Uint", aOffsets*)
    ;           Writes various integer type values to the process.
    ; Parameters:
    ;       address -   The memory address to which data will be written or if using the offset parameter, 
    ;                   the base address of the pointer.
    ;       type    -   The integer type. 
    ;                   Valid types are UChar, Char, UShort, Short, UInt, Int, Float, Int64 and Double. 
    ;                   Note: Types must not contain spaces i.e. " UInt" or "UInt " will not work. 
    ;                   When an invalid type is passed the method returns NULL and sets ErrorLevel to -2
    ;       aOffsets* - A variadic list of offsets. When using offsets the address parameter should equal the base address of the pointer.
    ;                   The address (base address) and offsets should point to the memory address which is to be written to.
    ; Return Values:
    ;       Non Zero -  Indicates success.
    ;       Zero     -  Indicates failure. Check errorLevel and A_LastError for more information
    ;       Null    -   An invalid type was passed. Errorlevel is set to -2

    write(address, value, type := "Uint", aOffsets*)
    {
        if !this.aTypeSize.hasKey(type)
            return "", ErrorLevel := -2
        sizeBytes := this.aTypeSize[type]
        if DllCall("WriteProcessMemory", "Ptr", this.hProcess, "Ptr", aOffsets.maxIndex() ? this.getAddressFromOffsets(address, aOffsets*) : address, type "*", value, "Ptr", sizeBytes, "Ptr", this.pNumberOfBytesWritten) 
        return address + sizeBytes
    }

    ; Method:   writeRaw(address, pBuffer, sizeBytes, aOffsets*)
    ;           Writes a buffer to the process.
    ; Parameters:
    ;   address -       The memory address to which the contents of the buffer will be written 
    ;                   or if using the offset parameter, the base address of the pointer.    
    ;   pBuffer -       A pointer to the buffer which is to be written.
    ;                   This does not necessarily have to be the beginning of the buffer itself e.g. pBuffer := &buffer + offset
    ;   sizeBytes -     The number of bytes which are to be written from the buffer.
    ;   aOffsets* -     A variadic list of offsets. When using offsets the address parameter should equal the base address of the pointer.
    ;                   The address (base address) and offsets should point to the memory address which is to be written to.
    ; Return Values:
    ;       Non Zero -  Indicates success.
    ;       Zero     -  Indicates failure. Check errorLevel and A_LastError for more information

    writeRaw(address, pBuffer, sizeBytes, aOffsets*)
    {
        if DllCall("WriteProcessMemory", "Ptr", this.hProcess, "Ptr", aOffsets.maxIndex() ? this.getAddressFromOffsets(address, aOffsets*) : address, "Ptr", pBuffer, "Ptr", sizeBytes, "Ptr", this.pNumberOfBytesWritten)
        return address + sizeBytes
    }

    ; Method:   writeBytes(address, hexStringOrByteArray, aOffsets*)
    ;           Writes a sequence of byte values to the process.
    ; Parameters:
    ;   address -       The memory address to where the bytes will be written 
    ;                   or if using the offset parameter, the base address of the pointer.    
    ;   hexStringOrByteArray -  This can either be either a string (A) or an object/array (B) containing the values to be written.
    ;              
    ;               A) HexString -      A string of hex bytes.  The '0x' hex prefix is optional.
    ;                                   Bytes can optionally be separated using the space or tab characters.
    ;                                   Each byte must be two characters in length i.e. '04' or '0x04' (not '4' or '0x4') 
    ;               B) Object/Array -   An array containing hex or decimal byte values e.g. array := [10, 29, 0xA]
    ;
    ;   aOffsets* -     A variadic list of offsets. When using offsets the address parameter should equal the base address of the pointer.
    ;                   The address (base address) and offsets should point to the memory address which is to be written to.
    ; Return Values:
    ;       -1, -2, -3, -4  - Error with the hexstring. Refer to hexStringToPattern() for details.
    ;       Other Non Zero  - Indicates success.
    ;       Zero            - Indicates write failure. Check errorLevel and A_LastError for more information
    ;
    ;   Examples:
    ;                   writeBytes(0xAABBCC11, "DEADBEEF")          ; Writes the bytes DE AD BE EF starting at address  0xAABBCC11
    ;                   writeBytes(0xAABBCC11, [10, 20, 0xA, 2])

    writeBytes(address, hexStringOrByteArray, aOffsets*)
    {
        if !IsObject(hexStringOrByteArray)
        {
            if !IsObject(hexStringOrByteArray := this.hexStringToPattern(hexStringOrByteArray))
                return hexStringOrByteArray
        }
        sizeBytes := this.getNeedleFromAOBPattern("", buffer, hexStringOrByteArray*)
        return this.writeRaw(address, &buffer, sizeBytes, aOffsets*)
    }

    ; Method:           pointer(address, finalType := "UInt", offsets*)
    ;                   This is an internal method. Since the other various methods all offer this functionality, they should be used instead.
    ;                   This will read integer values of both pointers and non-pointers (i.e. a single memory address)
    ; Parameters:
    ;   address -       The base address of the pointer or the memory address for a non-pointer.
    ;   finalType -     The type of integer stored at the final address.
    ;                   Valid types are UChar, Char, UShort, Short, UInt, Int, Float, Int64 and Double. 
    ;                   Note: Types must not contain spaces i.e. " UInt" or "UInt " will not work. 
    ;                   When an invalid type is passed the method returns NULL and sets ErrorLevel to -2
    ;   aOffsets* -     A variadic list of offsets used to calculate the pointers final address.
    ; Return Values: (The same as the read() method)
    ;       integer -   Indicates success.
    ;       Null    -   Indicates failure. Check ErrorLevel and A_LastError for more information.
    ;       Note:       Since the returned integer value may be 0, to check for success/failure compare the result
    ;                   against null i.e. if (result = "") then an error has occurred.
    ;                   If the target application is 64bit the pointers are read as an 8 byte Int64 (this.PtrType)
    
    pointer(address, finalType := "UInt", offsets*)
    { 
        For index, offset in offsets
            address := this.Read(address, this.ptrType) + offset 
        Return this.Read(address, finalType)
    }

    ; Method:               getAddressFromOffsets(address, aOffsets*)
    ;                       Returns the final address of a pointer.
    ;                       This is an internal method used by various methods however, this method may be useful if you are 
    ;                       looking to eliminate the overhead overhead associated with reading pointers which only change 
    ;                       on startup or map/level change. In other words you can cache the final address and
    ;                       read from this address directly.
    ; Parameters:
    ;   address             The base address of the pointer.
    ;   aOffsets*           A variadic list of offsets used to calculate the pointers final address.
    ;                       At least one offset must be present.
    ; Return Values:    
    ;   Positive integer    The final memory address pointed to by the pointer.
    ;   Negative integer    Failure
    ;   Null                Failure
    ; Note:                 If the target application is 64bit the pointers are read as an 8 byte Int64 (this.PtrType)

    getAddressFromOffsets(address, aOffsets*)
    {
        return  aOffsets.Remove() + this.pointer(address, this.ptrType, aOffsets*) ; remove the highest key so can use pointer() to find final memory address (minus the last offset)       
    }

    ; Interesting note:
    ; Although handles are 64-bit pointers, only the less significant 32 bits are employed in them for the purpose 
    ; of better compatibility (for example, to enable 32-bit and 64-bit processes interact with each other)
    ; Here are examples of such types: HANDLE, HWND, HMENU, HPALETTE, HBITMAP, etc. 
    ; http://www.viva64.com/en/k/0005/



    ; Method:   getProcessBaseAddress(WindowTitle, windowMatchMode := 3)
    ;           Returns the base address of a process. In most cases this will provide the same result as calling getModuleBaseAddress() (when passing 
    ;           a null value as the module parameter), however getProcessBaseAddress() will usually work regardless of the bitness
    ;           of both the AHK exe and the target process.
    ;           *This method relies on the target process having a window and will not work for console apps*
    ;           *'DetectHiddenWindows, On' is required for hidden windows*
    ;           ***If this returns an incorrect value, try using (the MORE RELIABLE) getModuleBaseAddress() instead.***
    ; Parameters:
    ;   windowTitle         This can be any AHK windowTitle identifier, such as 
    ;                       ahk_exe, ahk_class, ahk_pid, or simply the window title. e.g. "ahk_exe calc.exe" or "Calculator".
    ;                       It's safer not to use the window title, as some things can have the same window title e.g. an open folder called "Starcraft II"
    ;                       would have the same window title as the game itself.
    ;   windowMatchMode     Determines the matching mode used when finding the program's window (windowTitle).
    ;                       The default value is 3 i.e. an exact match. The current matchmode will be used if the parameter is null or 0.
    ;                       Refer to AHK's setTitleMathMode for more information.
    ; Return Values:
    ;   Positive integer    The base address of the process (success).
    ;   Null                The process's window couldn't be found.
    ;   0                   The GetWindowLong or GetWindowLongPtr call failed. Try getModuleBaseAddress() instead.
                           
  
    getProcessBaseAddress(windowTitle, windowMatchMode := "3")   
    {
        if (windowMatchMode && A_TitleMatchMode != windowMatchMode)
        {
            mode := A_TitleMatchMode ; This is a string and will not contain the 0x prefix
            StringReplace, windowMatchMode, windowMatchMode, 0x ; remove hex prefix as SetTitleMatchMode will throw a run time error. This will occur if integer mode is set to hex and matchmode param is passed as an number not a string.
            SetTitleMatchMode, %windowMatchMode%    ;mode 3 is an exact match
        }
        WinGet, hWnd, ID, %WindowTitle%
        if mode
            SetTitleMatchMode, %mode%    ; In case executed in autoexec
        if !hWnd
            return ; return blank failed to find window
       ; GetWindowLong returns a Long (Int) and GetWindowLongPtr return a Long_Ptr
        return DllCall(A_PtrSize = 4     ; If DLL call fails, returned value will = 0
            ? "GetWindowLong"
            : "GetWindowLongPtr"
            , "Ptr", hWnd, "Int", -6, A_Is64bitOS ? "Int64" : "UInt")  
            ; For the returned value when the OS is 64 bit use Int64 to prevent negative overflow when AHK is 32 bit and target process is 64bit 
            ; however if the OS is 32 bit, must use UInt, otherwise the number will be huge (however it will still work as the lower 4 bytes are correct)      
            ; Note - it's the OS bitness which matters here, not the scripts/AHKs
    }   

    ; http://winprogger.com/getmodulefilenameex-enumprocessmodulesex-failures-in-wow64/
    ; http://stackoverflow.com/questions/3801517/how-to-enum-modules-in-a-64bit-process-from-a-32bit-wow-process

    ; Method:            getModuleBaseAddress(module := "", byRef aModuleInfo := "")
    ; Parameters:
    ;   moduleName -    The file name of the module/dll to find e.g. "calc.exe", "GDI32.dll", "Bass.dll" etc
    ;                   If no module (null) is specified, the address of the base module - main()/process will be returned 
    ;                   e.g. for calc.exe the following two method calls are equivalent getModuleBaseAddress() and getModuleBaseAddress("calc.exe")
    ;   aModuleInfo -   (Optional) A module Info object is returned in this variable. If method fails this variable is made blank.
    ;                   This object contains the keys: name, fileName, lpBaseOfDll, SizeOfImage, and EntryPoint 
    ; Return Values: 
    ;   Positive integer - The module's base/load address (success).
    ;   -1 - Module not found
    ;   -3 - EnumProcessModulesEx failed
    ;   -4 - The AHK script is 32 bit and you are trying to access the modules of a 64 bit target process. Or the target process has been closed.
    ; Notes:    A 64 bit AHK can enumerate the modules of a target 64 or 32 bit process.
    ;           A 32 bit AHK can only enumerate the modules of a 32 bit process
    ;           This method requires PROCESS_QUERY_INFORMATION + PROCESS_VM_READ access rights. These are included by default with this class.
    GetDllBaseAddress(moduleName)
    {
        hS := DllCall("CreateToolhelp32Snapshot", "UInt", 0x18, "UInt", this.PID)
        NumPut(VarSetCapacity(me, (A_PtrSize = 8 ? 568 : 548), 0), me, "UInt")
        ModuleAdd:=DllCall("Module32First", "ptr", hS, "ptr", &me)
        while (ModuleAdd)
        {
            if (ModuleName = StrGet(&me+ (A_PtrSize = 8 ? 48 : 32), 256, "cp0"))
            {
                DllCall("CloseHandle", "ptr", hS)
                return NumGet(me, (A_PtrSize = 8 ? 24 : 20), "uptr")
            }
            ModuleAdd:=DllCall("Module32Next", "ptr", hS, "ptr", &me)
        }
    }
    getModuleBaseAddress(moduleName := "", byRef aModuleInfo := "")
    {
        aModuleInfo := ""
        if (moduleName = "")
            moduleName := this.GetModuleFileNameEx(0, True) ; main executable module of the process - get just fileName no path
        if r := this.getModules(aModules, True) < 0
            return r ; -4, -3
        return aModules.HasKey(moduleName) ? (aModules[moduleName].lpBaseOfDll, aModuleInfo := aModules[moduleName]) : -1
        ; no longer returns -5 for failed to get module info
    }  
     

    ; Method:                   getModuleFromAddress(address, byRef aModuleInfo) 
    ;                           Finds the module in which the address resides. 
    ; Parameters:
    ;   address                 The address of interest.
    ;                       
    ;   aModuleInfo             (Optional) An unquoted variable name. If the module associated with the address is found,
    ;                           a moduleInfo object will be stored in this variable. This object has the 
    ;                           following keys: name, fileName, lpBaseOfDll, SizeOfImage, and EntryPoint. 
    ;                           If the address is not found to reside inside a module, the passed variable is
    ;                           made blank/null.
    ;   offsetFromModuleBase    (Optional) Stores the relative offset from the module base address 
    ;                           to the specified address. If the method fails then the passed variable is set to blank/empty.
    ; Return Values:
    ;   1                       Success - The address is contained within a module.
    ;   -1                      The specified address does not reside within a loaded module.
    ;   -3                      EnumProcessModulesEx failed.
    ;   -4                      The AHK script is 32 bit and you are trying to access the modules of a 64 bit target process.      

    getModuleFromAddress(address, byRef aModuleInfo, byRef offsetFromModuleBase := "") 
    {
        aModuleInfo := offsetFromModule := ""
        if result := this.getmodules(aModules) < 0
            return result ; error -3, -4
        for k, module in aModules 
        {
            if (address >= module.lpBaseOfDll && address < module.lpBaseOfDll + module.SizeOfImage)
                return 1, aModuleInfo := module, offsetFromModuleBase := address - module.lpBaseOfDll
        }    
        return -1    
    }

    ; SeDebugPrivileges is required to read/write memory in some programs.
    ; This only needs to be called once when the script starts,
    ; regardless of the number of programs being read (or if the target programs restart)
    ; Call this before attempting to call any other methods in this class 
    ; i.e. call _ClassMemory.setSeDebugPrivilege() at the very start of the script.

    setSeDebugPrivilege(enable := True)
    {
        h := DllCall("OpenProcess", "UInt", 0x0400, "Int", false, "UInt", DllCall("GetCurrentProcessId"), "Ptr")
        ; Open an adjustable access token with this process (TOKEN_ADJUST_PRIVILEGES = 32)
        DllCall("Advapi32.dll\OpenProcessToken", "Ptr", h, "UInt", 32, "PtrP", t)
        VarSetCapacity(ti, 16, 0)  ; structure of privileges
        NumPut(1, ti, 0, "UInt")  ; one entry in the privileges array...
        ; Retrieves the locally unique identifier of the debug privilege:
        DllCall("Advapi32.dll\LookupPrivilegeValue", "Ptr", 0, "Str", "SeDebugPrivilege", "Int64P", luid)
        NumPut(luid, ti, 4, "Int64")
        if enable
            NumPut(2, ti, 12, "UInt")  ; enable this privilege: SE_PRIVILEGE_ENABLED = 2
        ; Update the privileges of this process with the new access token:
        r := DllCall("Advapi32.dll\AdjustTokenPrivileges", "Ptr", t, "Int", false, "Ptr", &ti, "UInt", 0, "Ptr", 0, "Ptr", 0)
        DllCall("CloseHandle", "Ptr", t)  ; close this access token handle to save memory
        DllCall("CloseHandle", "Ptr", h)  ; close this process handle to save memory
        return r
    }


    ; Method:  isTargetProcess64Bit(PID, hProcess := "", currentHandleAccess := "")
    ;          Determines if a process is 64 bit.
    ; Parameters:
    ;   PID                     The Process ID of the target process. If required this is used to open a temporary process handle.  
    ;   hProcess                (Optional) A handle to the process, as returned by openProcess() i.e. [derivedObject].hProcess
    ;   currentHandleAccess     (Optional) The dwDesiredAccess value used when opening the process handle which has been 
    ;                           passed as the hProcess parameter. If specifying hProcess, you should also specify this value.                 
    ; Return Values:
    ;   True    The target application is 64 bit.
    ;   False   The target application is 32 bit.
    ;   Null    The method failed.
    ; Notes:
    ;   This is an internal method which is called when the new operator is used. It is used to set the pointer type for 32/64 bit applications so the pointer methods will work.
    ;   This operation requires a handle with PROCESS_QUERY_INFORMATION or PROCESS_QUERY_LIMITED_INFORMATION access rights.
    ;   If the currentHandleAccess parameter does not contain these rights (or not passed) or if the hProcess (process handle) is invalid (or not passed)
    ;   a temporary handle is opened to perform this operation. Otherwise if hProcess and currentHandleAccess appear valid  
    ;   the passed hProcess is used to perform the operation.

    isTargetProcess64Bit(PID, hProcess := "", currentHandleAccess := "")
    {
        if !A_Is64bitOS
            return False 
        ; If insufficient rights, open a temporary handle
        else if !hProcess || !(currentHandleAccess & (this.aRights.PROCESS_QUERY_INFORMATION | this.aRights.PROCESS_QUERY_LIMITED_INFORMATION))
            closeHandle := hProcess := this.openProcess(PID, this.aRights.PROCESS_QUERY_INFORMATION)
        if (hProcess && DllCall("IsWow64Process", "Ptr", hProcess, "Int*", Wow64Process))
            result := !Wow64Process
        return result, closeHandle ? this.CloseHandle(hProcess) : ""
    }
    /*
        _Out_  PBOOL Wow64Proces value set to:
        True if the process is running under WOW64 - 32bit app on 64bit OS.
        False if the process is running under 32-bit Windows!
        False if the process is a 64-bit application running under 64-bit Windows.
    */  

    ; Method: suspend() / resume()
    ; Notes:
    ;   These are undocumented Windows functions which suspend and resume the process. Here be dragons.
    ;   The process handle must have PROCESS_SUSPEND_RESUME access rights. 
    ;   That is, you must specify this when using the new operator, as it is not included. 
    ;   Some people say it requires more rights and just use PROCESS_ALL_ACCESS, however PROCESS_SUSPEND_RESUME has worked for me.
    ;   Suspending a process manually can be quite helpful when reversing memory addresses and pointers, although it's not at all required. 
    ;   As an unorthodox example, memory addresses holding pointers are often stored in a slightly obfuscated manner i.e. they require bit operations to calculate their
    ;   true stored value (address). This obfuscation can prevent Cheat Engine from finding the true origin of a pointer or links to other memory regions. If there 
    ;   are no static addresses between the obfuscated address and the final destination address then CE wont find anything (there are ways around this in CE). One way around this is to
    ;   suspend the process, write the true/deobfuscated value to the address and then perform your scans. Afterwards write back the original values and resume the process.

    suspend()
    {
        return DllCall("ntdll\NtSuspendProcess", "Ptr", this.hProcess)
    }  

    resume()
    {
        return DllCall("ntdll\NtResumeProcess", "Ptr", this.hProcess)
    } 

    ; Method:               getModules(byRef aModules, useFileNameAsKey := False)
    ;                       Stores the process's loaded modules as an array of (object) modules in the aModules parameter.
    ; Parameters:
    ;   aModules            An unquoted variable name. The loaded modules of the process are stored in this variable as an array of objects.
    ;                       Each object in this array has the following keys: name, fileName, lpBaseOfDll, SizeOfImage, and EntryPoint. 
    ;   useFileNameAsKey    When true, the file name e.g. GDI32.dll is used as the lookup key for each module object.
    ; Return Values:
    ;   Positive integer    The size of the aModules array. (Success)
    ;   -3                  EnumProcessModulesEx failed.
    ;   -4                  The AHK script is 32 bit and you are trying to access the modules of a 64 bit target process.

    getModules(byRef aModules, useFileNameAsKey := False)
    {
        if (A_PtrSize = 4 && this.IsTarget64bit)
            return -4 ; AHK is 32bit and target process is 64 bit, this function wont work     
        aModules := []
        if !moduleCount := this.EnumProcessModulesEx(lphModule)
            return -3  
        loop % moduleCount
        {
            this.GetModuleInformation(hModule := numget(lphModule, (A_index - 1) * A_PtrSize), aModuleInfo)
            aModuleInfo.Name := this.GetModuleFileNameEx(hModule)
            filePath := aModuleInfo.name
            SplitPath, filePath, fileName
            aModuleInfo.fileName := fileName
            if useFileNameAsKey
                aModules[fileName] := aModuleInfo
            else aModules.insert(aModuleInfo)
        }
        return moduleCount        
    }



    getEndAddressOfLastModule(byRef aModuleInfo := "")
    {
        if !moduleCount := this.EnumProcessModulesEx(lphModule)
            return -3     
        hModule := numget(lphModule, (moduleCount - 1) * A_PtrSize)
        if this.GetModuleInformation(hModule, aModuleInfo)
            return aModuleInfo.lpBaseOfDll + aModuleInfo.SizeOfImage
        return -5
    }

    ; lpFilename [out]
    ; A pointer to a buffer that receives the fully qualified path to the module. 
    ; If the size of the file name is larger than the value of the nSize parameter, the function succeeds 
    ; but the file name is truncated and null-terminated.
    ; If the buffer is adequate the string is still null terminated. 

    GetModuleFileNameEx(hModule := 0, fileNameNoPath := False)
    {
        ; ANSI MAX_PATH = 260 (includes null) - unicode can be ~32K.... but no one would ever have one that size
        ; So just give it a massive size and don't bother checking. Most coders just give it MAX_PATH size anyway
        VarSetCapacity(lpFilename, 2048 * (A_IsUnicode ? 2 : 1)) 
        DllCall("psapi\GetModuleFileNameEx"
                    , "Ptr", this.hProcess
                    , "Ptr", hModule
                    , "Str", lpFilename
                    , "Uint", 2048 / (A_IsUnicode ? 2 : 1))
        if fileNameNoPath
            SplitPath, lpFilename, lpFilename ; strips the path so = GDI32.dll

        return lpFilename
    }

    ; dwFilterFlag
    ;   LIST_MODULES_DEFAULT    0x0  
    ;   LIST_MODULES_32BIT      0x01
    ;   LIST_MODULES_64BIT      0x02
    ;   LIST_MODULES_ALL        0x03
    ; If the function is called by a 32-bit application running under WOW64, the dwFilterFlag option 
    ; is ignored and the function provides the same results as the EnumProcessModules function.
    EnumProcessModulesEx(byRef lphModule, dwFilterFlag := 0x03)
    {
        lastError := A_LastError
        size := VarSetCapacity(lphModule, 4)
        loop 
        {
            DllCall("psapi\EnumProcessModulesEx"
                        , "Ptr", this.hProcess
                        , "Ptr", &lphModule
                        , "Uint", size
                        , "Uint*", reqSize
                        , "Uint", dwFilterFlag)
            if ErrorLevel
                return 0
            else if (size >= reqSize)
                break
            else size := VarSetCapacity(lphModule, reqSize)  
        }
        ; On first loop it fails with A_lastError = 0x299 as its meant to
        ; might as well reset it to its previous version
        DllCall("SetLastError", "UInt", lastError)
        return reqSize // A_PtrSize ; module count  ; sizeof(HMODULE) - enumerate the array of HMODULEs     
    }

    GetModuleInformation(hModule, byRef aModuleInfo)
    {
        VarSetCapacity(MODULEINFO, A_PtrSize * 3), aModuleInfo := []
        return DllCall("psapi\GetModuleInformation"
                    , "Ptr", this.hProcess
                    , "Ptr", hModule
                    , "Ptr", &MODULEINFO
                    , "UInt", A_PtrSize * 3)
                , aModuleInfo := {  lpBaseOfDll: numget(MODULEINFO, 0, "Ptr")
                                ,   SizeOfImage: numget(MODULEINFO, A_PtrSize, "UInt")
                                ,   EntryPoint: numget(MODULEINFO, A_PtrSize * 2, "Ptr") }
    }

    ; Method:           hexStringToPattern(hexString)
    ;                   Converts the hex string parameter into an array of bytes pattern (AOBPattern) that
    ;                   can be passed to the various pattern scan methods i.e.  modulePatternScan(), addressPatternScan(), rawPatternScan(), and processPatternScan()
    ;       
    ; Parameters:
    ;   hexString -     A string of hex bytes.  The '0x' hex prefix is optional.
    ;                   Bytes can optionally be separated using the space or tab characters.
    ;                   Each byte must be two characters in length i.e. '04' or '0x04' (not '4' or '0x4') 
    ;                   ** Unlike the other methods, wild card bytes MUST be denoted using '??' (two question marks)** 
    ;
    ; Return Values: 
    ;   Object          Success - The returned object contains the AOB pattern. 
    ;   -1              An empty string was passed.
    ;   -2              Non hex character present.  Acceptable characters are A-F, a-F, 0-9, ?, space, tab, and 0x (hex prefix).
    ;   -3              Non-even wild card character count. One of the wild card bytes is missing a '?' e.g. '?' instead of '??'.               
    ;   -4              Non-even character count. One of the hex bytes is probably missing a character e.g. '4' instead of '04'.
    ;
    ;   Examples:
    ;                   pattern := hexStringToPattern("DEADBEEF02")
    ;                   pattern := hexStringToPattern("0xDE0xAD0xBE0xEF0x02")
    ;                   pattern := hexStringToPattern("DE AD BE EF 02")
    ;                   pattern := hexStringToPattern("0xDE 0xAD 0xBE 0xEF 0x02")
    ;               
    ;                   This will mark the third byte as wild:
    ;                   pattern := hexStringToPattern("DE AD ?? EF 02")
    ;                   pattern := hexStringToPattern("0xDE 0xAD ?? 0xEF 0x02")
    ;               
    ;                   The returned pattern can then be passed to the various pattern scan methods, for example:
    ;                   pattern := hexStringToPattern("DE AD BE EF 02")
    ;                   memObject.processPatternScan(,, pattern*)   ; Note the '*'

    hexStringToPattern(hexString)
    {
        AOBPattern := []
        hexString := RegExReplace(hexString, "(\s|0x)")
        StringReplace, hexString, hexString, ?, ?, UseErrorLevel
        wildCardCount := ErrorLevel

        if !length := StrLen(hexString)
            return -1 ; no str
        else if RegExMatch(hexString, "[^0-9a-fA-F?]")
            return -2 ; non hex character and not a wild card
        else if Mod(wildCardCount, 2)
            return -3 ; non-even wild card character count
        else if Mod(length, 2)
            return -4 ; non-even character count
        loop, % length/2
        {
            value := "0x" SubStr(hexString, 1 + 2 * (A_index-1), 2)
            AOBPattern.Insert(value + 0 = "" ? "?" : value)
        }
        return AOBPattern
    }

    ; Method:           stringToPattern(string, encoding := "UTF-8", insertNullTerminator := False)
    ;                   Converts a text string parameter into an array of bytes pattern (AOBPattern) that
    ;                   can be passed to the various pattern scan methods i.e.  modulePatternScan(), addressPatternScan(), rawPatternScan(), and processPatternScan()
    ; 
    ; Parameters:
    ;   string                  The text string to convert.
    ;   encoding                This refers to how the string is stored in the program's memory.
    ;                           UTF-8 and UTF-16 are common. Refer to the AHK manual for other encoding types.  
    ;   insertNullTerminator    Includes the null terminating byte(s) (at the end of the string) in the AOB pattern.
    ;                           This should be set to 'false' unless you are certain that the target string is null terminated and you are searching for the entire string or the final part of the string.
    ;
    ; Return Values: 
    ;   Object          Success - The returned object contains the AOB pattern. 
    ;   -1              An empty string was passed.
    ;
    ;   Examples:
    ;                   pattern := stringToPattern("This text exists somewhere in the target program!")
    ;                   memObject.processPatternScan(,, pattern*)   ; Note the '*'

    stringToPattern(string, encoding := "UTF-8", insertNullTerminator := False)
    {   
        if !length := StrLen(string)
            return -1 ; no str  
        AOBPattern := []
        encodingSize := (encoding = "utf-16" || encoding = "cp1200") ? 2 : 1
        requiredSize := StrPut(string, encoding) * encodingSize - (insertNullTerminator ? 0 : encodingSize)
        VarSetCapacity(buffer, requiredSize)
        StrPut(string, &buffer, length + (insertNullTerminator ?  1 : 0), encoding) 
        loop, % requiredSize
            AOBPattern.Insert(NumGet(buffer, A_Index-1, "UChar"))
        return AOBPattern
    }    

 
    ; Method:           modulePatternScan(module := "", aAOBPattern*)
    ;                   Scans the specified module for the specified array of bytes    
    ; Parameters:
    ;   module -        The file name of the module/dll to search e.g. "calc.exe", "GDI32.dll", "Bass.dll" etc
    ;                   If no module (null) is specified, the executable file of the process will be used. 
    ;                   e.g. for calc.exe it would be the same as calling modulePatternScan(, aAOBPattern*) or modulePatternScan("calc.exe", aAOBPattern*)
    ;   aAOBPattern*    A variadic list of byte values i.e. the array of bytes to find.
    ;                   Wild card bytes should be indicated by passing a non-numeric value eg "?".
    ; Return Values:
    ;   Positive int    Success. The memory address of the found pattern.   
    ;   Null            Failed to find or retrieve the specified module. ErrorLevel is set to the returned error from getModuleBaseAddress()
    ;                   refer to that method for more information.
    ;   0               The pattern was not found inside the module
    ;   -9              VirtualQueryEx() failed
    ;   -10             The aAOBPattern* is invalid. No bytes were passed                   

    modulePatternScan(module := "", aAOBPattern*)
    {
        MEM_COMMIT := 0x1000, MEM_MAPPED := 0x40000, MEM_PRIVATE := 0x20000
        , PAGE_NOACCESS := 0x01, PAGE_GUARD := 0x100

        if (result := this.getModuleBaseAddress(module, aModuleInfo)) <= 0
             return "", ErrorLevel := result ; failed    
        if !patternSize := this.getNeedleFromAOBPattern(patternMask, AOBBuffer, aAOBPattern*)
            return -10 ; no pattern
        ; Try to read the entire module in one RPM()
        ; If fails with access (-1) iterate the modules memory pages and search the ones which are readable          
        if (result := this.PatternScan(aModuleInfo.lpBaseOfDll, aModuleInfo.SizeOfImage, patternMask, AOBBuffer)) >= 0
            return result  ; Found / not found
        ; else RPM() failed lets iterate the pages
        address := aModuleInfo.lpBaseOfDll
        endAddress := address + aModuleInfo.SizeOfImage
        loop 
        {
            if !this.VirtualQueryEx(address, aRegion)
                return -9
            if (aRegion.State = MEM_COMMIT 
            && !(aRegion.Protect & (PAGE_NOACCESS | PAGE_GUARD)) ; can't read these areas
            ;&& (aRegion.Type = MEM_MAPPED || aRegion.Type = MEM_PRIVATE) ;Might as well read Image sections as well
            && aRegion.RegionSize >= patternSize
            && (result := this.PatternScan(address, aRegion.RegionSize, patternMask, AOBBuffer)) > 0)
                return result
        } until (address += aRegion.RegionSize) >= endAddress
        return 0       
    }

    ; Method:               addressPatternScan(startAddress, sizeOfRegionBytes, aAOBPattern*)
    ;                       Scans a specified memory region for an array of bytes pattern.
    ;                       The entire memory area specified must be readable for this method to work,
    ;                       i.e. you must ensure the area is readable before calling this method.
    ; Parameters:
    ;   startAddress        The memory address from which to begin the search.
    ;   sizeOfRegionBytes   The numbers of bytes to scan in the memory region.
    ;   aAOBPattern*        A variadic list of byte values i.e. the array of bytes to find.
    ;                       Wild card bytes should be indicated by passing a non-numeric value eg "?".      
    ; Return Values:
    ;   Positive integer    Success. The memory address of the found pattern.
    ;   0                   Pattern not found
    ;   -1                  Failed to read the memory region.
    ;   -10                 An aAOBPattern pattern. No bytes were passed.

    addressPatternScan(startAddress, sizeOfRegionBytes, aAOBPattern*)
    {
        if !this.getNeedleFromAOBPattern(patternMask, AOBBuffer, aAOBPattern*)
            return -10
        return this.PatternScan(startAddress, sizeOfRegionBytes, patternMask, AOBBuffer)   
    }
   
    ; Method:       processPatternScan(startAddress := 0, endAddress := "", aAOBPattern*)
    ;               Scan the memory space of the current process for an array of bytes pattern. 
    ;               To use this in a loop (scanning for multiple occurrences of the same pattern),
    ;               simply call it again passing the last found address + 1 as the startAddress.
    ; Parameters:
    ;   startAddress -      The memory address from which to begin the search.
    ;   endAddress -        The memory address at which the search ends. 
    ;                       Defaults to 0x7FFFFFFF for 32 bit target processes.
    ;                       Defaults to 0xFFFFFFFF for 64 bit target processes when the AHK script is 32 bit.
    ;                       Defaults to 0x7FFFFFFFFFF for 64 bit target processes when the AHK script is 64 bit. 
    ;                       0x7FFFFFFF and 0x7FFFFFFFFFF are the maximum process usable virtual address spaces for 32 and 64 bit applications.
    ;                       Anything higher is used by the system (unless /LARGEADDRESSAWARE and 4GT have been modified).            
    ;                       Note: The entire pattern must be occur inside this range for a match to be found. The range is inclusive.
    ;   aAOBPattern* -      A variadic list of byte values i.e. the array of bytes to find.
    ;                       Wild card bytes should be indicated by passing a non-numeric value eg "?".
    ; Return Values:
    ;   Positive integer -  Success. The memory address of the found pattern.
    ;   0                   The pattern was not found.
    ;   -1                  VirtualQueryEx() failed.
    ;   -2                  Failed to read a memory region.
    ;   -10                 The aAOBPattern* is invalid. (No bytes were passed)

    processPatternScan(startAddress := 0, endAddress := "", aAOBPattern*)
    {
        address := startAddress
        if endAddress is not integer  
            endAddress := this.isTarget64bit ? (A_PtrSize = 8 ? 0x7FFFFFFFFFF : 0xFFFFFFFF) : 0x7FFFFFFF

        MEM_COMMIT := 0x1000, MEM_MAPPED := 0x40000, MEM_PRIVATE := 0x20000
        PAGE_NOACCESS := 0x01, PAGE_GUARD := 0x100
        if !patternSize := this.getNeedleFromAOBPattern(patternMask, AOBBuffer, aAOBPattern*)
            return -10  
        while address <= endAddress ; > 0x7FFFFFFF - definitely reached the end of the useful area (at least for a 32 target process)
        {
            if !this.VirtualQueryEx(address, aInfo)
                return -1
            if A_Index = 1
                aInfo.RegionSize -= address - aInfo.BaseAddress
            if (aInfo.State = MEM_COMMIT) 
            && !(aInfo.Protect & (PAGE_NOACCESS | PAGE_GUARD)) ; can't read these areas
            ;&& (aInfo.Type = MEM_MAPPED || aInfo.Type = MEM_PRIVATE) ;Might as well read Image sections as well
            && aInfo.RegionSize >= patternSize
            && (result := this.PatternScan(address, aInfo.RegionSize, patternMask, AOBBuffer))
            {
                if result < 0 
                    return -2
                else if (result + patternSize - 1 <= endAddress)
                    return result
                else return 0
            }
            address += aInfo.RegionSize
        }
        return 0
    }

    ; Method:           rawPatternScan(byRef buffer, sizeOfBufferBytes := "", aAOBPattern*)   
    ;                   Scans a binary buffer for an array of bytes pattern. 
    ;                   This is useful if you have already dumped a region of memory via readRaw()
    ; Parameters:
    ;   buffer              The binary buffer to be searched.
    ;   sizeOfBufferBytes   The size of the binary buffer. If null or 0 the size is automatically retrieved.
    ;   startOffset         The offset from the start of the buffer from which to begin the search. This must be >= 0.
    ;   aAOBPattern*        A variadic list of byte values i.e. the array of bytes to find.
    ;                       Wild card bytes should be indicated by passing a non-numeric value eg "?".
    ; Return Values:
    ;   >= 0                The offset of the pattern relative to the start of the haystack.
    ;   -1                  Not found.
    ;   -2                  Parameter incorrect.

    rawPatternScan(byRef buffer, sizeOfBufferBytes := "", startOffset := 0, aAOBPattern*)
    {
        if !this.getNeedleFromAOBPattern(patternMask, AOBBuffer, aAOBPattern*)
            return -10
        if (sizeOfBufferBytes + 0 = "" || sizeOfBufferBytes <= 0)
            sizeOfBufferBytes := VarSetCapacity(buffer)
        if (startOffset + 0 = "" || startOffset < 0)
            startOffset := 0
        return this.bufferScanForMaskedPattern(&buffer, sizeOfBufferBytes, patternMask, &AOBBuffer, startOffset)           
    }

    ; Method:           getNeedleFromAOBPattern(byRef patternMask, byRef needleBuffer, aAOBPattern*)
    ;                   Converts an array of bytes pattern (aAOBPattern*) into a binary needle and pattern mask string
    ;                   which are compatible with patternScan() and bufferScanForMaskedPattern().
    ;                   The modulePatternScan(), addressPatternScan(), rawPatternScan(), and processPatternScan() methods
    ;                   allow you to directly search for an array of bytes pattern in a single method call.
    ; Parameters:
    ;   patternMask -   (output) A string which indicates which bytes are wild/non-wild.
    ;   needleBuffer -  (output) The array of bytes passed via aAOBPattern* is converted to a binary needle and stored inside this variable.
    ;   aAOBPattern* -  (input) A variadic list of byte values i.e. the array of bytes from which to create the patternMask and needleBuffer.
    ;                   Wild card bytes should be indicated by passing a non-numeric value eg "?".
    ; Return Values:
    ;  The number of bytes in the binary needle and hence the number of characters in the patternMask string. 

    getNeedleFromAOBPattern(byRef patternMask, byRef needleBuffer, aAOBPattern*)
    {
        patternMask := "", VarSetCapacity(needleBuffer, aAOBPattern.MaxIndex())
        for i, v in aAOBPattern
            patternMask .= (v + 0 = "" ? "?" : "x"), NumPut(round(v), needleBuffer, A_Index - 1, "UChar")
        return round(aAOBPattern.MaxIndex())
    }

    ; The handle must have been opened with the PROCESS_QUERY_INFORMATION access right
    VirtualQueryEx(address, byRef aInfo)
    {

        if (aInfo.__Class != "_ClassMemory._MEMORY_BASIC_INFORMATION")
            aInfo := new this._MEMORY_BASIC_INFORMATION()
        return aInfo.SizeOfStructure = DLLCall("VirtualQueryEx" 
                                                , "Ptr", this.hProcess
                                                , "Ptr", address
                                                , "Ptr", aInfo.pStructure
                                                , "Ptr", aInfo.SizeOfStructure
                                                , "Ptr") 
    }

    /*
    // The c++ function used to generate the machine code
    int scan(unsigned char* haystack, unsigned int haystackSize, unsigned char* needle, unsigned int needleSize, char* patternMask, unsigned int startOffset)
    {
        for (unsigned int i = startOffset; i <= haystackSize - needleSize; i++)
        {
            for (unsigned int j = 0; needle[j] == haystack[i + j] || patternMask[j] == '?'; j++)
            {
                if (j + 1 == needleSize)
                    return i;
            }
        }
        return -1;
    }
    */

    ; Method:               PatternScan(startAddress, sizeOfRegionBytes, patternMask, byRef needleBuffer)
    ;                       Scans a specified memory region for a binary needle pattern using a machine code function
    ;                       If found it returns the memory address of the needle in the processes memory.
    ; Parameters:
    ;   startAddress -      The memory address from which to begin the search.
    ;   sizeOfRegionBytes - The numbers of bytes to scan in the memory region.
    ;   patternMask -       This string indicates which bytes must match and which bytes are wild. Each wildcard byte must be denoted by a single '?'. 
    ;                       Non wildcards can use any other single character e.g 'x'. There should be no spaces.
    ;                       With the patternMask 'xx??x', the first, second, and fifth bytes must match. The third and fourth bytes are wild.
    ;    needleBuffer -     The variable which contains the binary needle. This needle should consist of UChar bytes.
    ; Return Values:
    ;   Positive integer    The address of the pattern.
    ;   0                   Pattern not found.
    ;   -1                  Failed to read the region.

    patternScan(startAddress, sizeOfRegionBytes, byRef patternMask, byRef needleBuffer)
    {
        if !this.readRaw(startAddress, buffer, sizeOfRegionBytes)
            return -1      
        if (offset := this.bufferScanForMaskedPattern(&buffer, sizeOfRegionBytes, patternMask, &needleBuffer)) >= 0
            return startAddress + offset 
        else return 0
    }
    ; Method:               bufferScanForMaskedPattern(byRef hayStack, sizeOfHayStackBytes, byRef patternMask, byRef needle)
    ;                       Scans a binary haystack for binary needle against a pattern mask string using a machine code function.
    ; Parameters:
    ;   hayStackAddress -   The address of the binary haystack which is to be searched.
    ;   sizeOfHayStackBytes The total size of the haystack in bytes.
    ;   patternMask -       A string which indicates which bytes must match and which bytes are wild. Each wildcard byte must be denoted by a single '?'. 
    ;                       Non wildcards can use any other single character e.g 'x'. There should be no spaces.
    ;                       With the patternMask 'xx??x', the first, second, and fifth bytes must match. The third and fourth bytes are wild.
    ;   needleAddress -     The address of the binary needle to find. This needle should consist of UChar bytes.
    ;   startOffset -       The offset from the start of the haystack from which to begin the search. This must be >= 0.
    ; Return Values:    
    ;   >= 0                Found. The pattern begins at this offset - relative to the start of the haystack.
    ;   -1                  Not found.
    ;   -2                  Invalid sizeOfHayStackBytes parameter - Must be > 0.

    ; Notes:
    ;       This is a basic function with few safeguards. Incorrect parameters may crash the script.

    bufferScanForMaskedPattern(hayStackAddress, sizeOfHayStackBytes, byRef patternMask, needleAddress, startOffset := 0)
    {
        static p
        if !p
        {
            if A_PtrSize = 4    
                p := this.MCode("1,x86:8B44240853558B6C24182BC5568B74242489442414573BF0773E8B7C241CBB010000008B4424242BF82BD8EB038D49008B54241403D68A0C073A0A740580383F750B8D0C033BCD74174240EBE98B442424463B74241876D85F5E5D83C8FF5BC35F8BC65E5D5BC3")
            else 
                p := this.MCode("1,x64:48895C2408488974241048897C2418448B5424308BF2498BD8412BF1488BF9443BD6774A4C8B5C24280F1F800000000033C90F1F400066660F1F840000000000448BC18D4101418D4AFF03C80FB60C3941380C18740743803C183F7509413BC1741F8BC8EBDA41FFC2443BD676C283C8FF488B5C2408488B742410488B7C2418C3488B5C2408488B742410488B7C2418418BC2C3")
        }
        if (needleSize := StrLen(patternMask)) + startOffset > sizeOfHayStackBytes
            return -1 ; needle can't exist inside this region. And basic check to prevent wrap around error of the UInts in the machine function       
        if (sizeOfHayStackBytes > 0)
            return DllCall(p, "Ptr", hayStackAddress, "UInt", sizeOfHayStackBytes, "Ptr", needleAddress, "UInt", needleSize, "AStr", patternMask, "UInt", startOffset, "cdecl int")
        return -2
    }

    ; Notes: 
    ; Other alternatives for non-wildcard buffer comparison.
    ; Use memchr to find the first byte, then memcmp to compare the remainder of the buffer against the needle and loop if it doesn't match
    ; The function FindMagic() by Lexikos uses this method.
    ; Use scanInBuf() machine code function - but this only supports 32 bit ahk. I could check if needle contains wild card and AHK is 32bit,
    ; then call this function. But need to do a speed comparison to see the benefits, but this should be faster. Although the benefits for 
    ; the size of the memory regions be dumped would most likely be inconsequential as it's already extremely fast.

    MCode(mcode)
    {
        static e := {1:4, 2:1}, c := (A_PtrSize=8) ? "x64" : "x86"
        if !regexmatch(mcode, "^([0-9]+),(" c ":|.*?," c ":)([^,]+)", m)
            return
        if !DllCall("crypt32\CryptStringToBinary", "str", m3, "uint", 0, "uint", e[m1], "ptr", 0, "uint*", s, "ptr", 0, "ptr", 0)
            return
        p := DllCall("GlobalAlloc", "uint", 0, "ptr", s, "ptr")
        ; if (c="x64") ; Virtual protect must always be enabled for both 32 and 64 bit. If DEP is set to all applications (not just systems), then this is required
        DllCall("VirtualProtect", "ptr", p, "ptr", s, "uint", 0x40, "uint*", op)
        if DllCall("crypt32\CryptStringToBinary", "str", m3, "uint", 0, "uint", e[m1], "ptr", p, "uint*", s, "ptr", 0, "ptr", 0)
            return p
        DllCall("GlobalFree", "ptr", p)
        return
    }

    ; This link indicates that the _MEMORY_BASIC_INFORMATION32/64 should be based on the target process
    ; http://stackoverflow.com/questions/20068219/readprocessmemory-on-a-64-bit-proces-always-returns-error-299 
    ; The msdn documentation is unclear, and suggests that a debugger can pass either structure - perhaps there is some other step involved.
    ; My tests seem to indicate that you must pass _MEMORY_BASIC_INFORMATION i.e. structure is relative to the AHK script bitness.
    ; Another post on the net also agrees with my results. 

    ; Notes: 
    ; A 64 bit AHK script can call this on a target 64 bit process. Issues may arise at extremely high memory addresses as AHK does not support UInt64 (but these addresses should never be used anyway).
    ; A 64 bit AHK can call this on a 32 bit target and it should work. 
    ; A 32 bit AHk script can call this on a 64 bit target and it should work providing the addresses fall inside the 32 bit range.

    class _MEMORY_BASIC_INFORMATION
    {
        __new()
        {   
            if !this.pStructure := DllCall("GlobalAlloc", "UInt", 0, "Ptr", this.SizeOfStructure := A_PtrSize = 8 ? 48 : 28, "Ptr")
                return ""
            return this
        }
        __Delete()
        {
            DllCall("GlobalFree", "Ptr", this.pStructure)
        }
        ; For 64bit the int64 should really be unsigned. But AHK doesn't support these
        ; so this won't work correctly for higher memory address areas
        __get(key)
        {
            static aLookUp := A_PtrSize = 8 
                                ?   {   "BaseAddress": {"Offset": 0, "Type": "Int64"}
                                    ,    "AllocationBase": {"Offset": 8, "Type": "Int64"}
                                    ,    "AllocationProtect": {"Offset": 16, "Type": "UInt"}
                                    ,    "RegionSize": {"Offset": 24, "Type": "Int64"}
                                    ,    "State": {"Offset": 32, "Type": "UInt"}
                                    ,    "Protect": {"Offset": 36, "Type": "UInt"}
                                    ,    "Type": {"Offset": 40, "Type": "UInt"} }
                                :   {  "BaseAddress": {"Offset": 0, "Type": "UInt"}
                                    ,   "AllocationBase": {"Offset": 4, "Type": "UInt"}
                                    ,   "AllocationProtect": {"Offset": 8, "Type": "UInt"}
                                    ,   "RegionSize": {"Offset": 12, "Type": "UInt"}
                                    ,   "State": {"Offset": 16, "Type": "UInt"}
                                    ,   "Protect": {"Offset": 20, "Type": "UInt"}
                                    ,   "Type": {"Offset": 24, "Type": "UInt"} }

            if aLookUp.HasKey(key)
                return numget(this.pStructure+0, aLookUp[key].Offset, aLookUp[key].Type)        
        }
        __set(key, value)
        {
             static aLookUp := A_PtrSize = 8 
                                ?   {   "BaseAddress": {"Offset": 0, "Type": "Int64"}
                                    ,    "AllocationBase": {"Offset": 8, "Type": "Int64"}
                                    ,    "AllocationProtect": {"Offset": 16, "Type": "UInt"}
                                    ,    "RegionSize": {"Offset": 24, "Type": "Int64"}
                                    ,    "State": {"Offset": 32, "Type": "UInt"}
                                    ,    "Protect": {"Offset": 36, "Type": "UInt"}
                                    ,    "Type": {"Offset": 40, "Type": "UInt"} }
                                :   {  "BaseAddress": {"Offset": 0, "Type": "UInt"}
                                    ,   "AllocationBase": {"Offset": 4, "Type": "UInt"}
                                    ,   "AllocationProtect": {"Offset": 8, "Type": "UInt"}
                                    ,   "RegionSize": {"Offset": 12, "Type": "UInt"}
                                    ,   "State": {"Offset": 16, "Type": "UInt"}
                                    ,   "Protect": {"Offset": 20, "Type": "UInt"}
                                    ,   "Type": {"Offset": 24, "Type": "UInt"} }

            if aLookUp.HasKey(key)
            {
                NumPut(value, this.pStructure+0, aLookUp[key].Offset, aLookUp[key].Type)            
                return value
            }
        }
        Ptr()
        {
            return this.pStructure
        }
        sizeOf()
        {
            return this.SizeOfStructure
        }
    }

}



 
