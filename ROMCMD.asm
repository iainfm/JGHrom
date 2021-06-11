\ ROMCMD/src
\ Command hander for Command/Help/Status/Config
\ by J.G.Harston
\ converted to beebasm format by Iain McLaren

kbd% = 3

\ OS Calls 
OSBYTE = &FFF4
OSARGS = &FFDA
OSASCI = &FFE3
OSNEWL = &FFE7
OSWRCH = &FFEE

\ Vectors
EVNTV  = &220
KEYV   = &228
INSV   = &22A

usb_D=&FCF8:usb_S=&FCF9
\ DIM mcode% &1000, L%-1

org &8000

\:O%=mcode%

.rombase
	EQUB	&00
	EQUW	RelocTable
	JMP		Service
	EQUB	&82
	EQUB	copyright-rombase
	
.ROMTitle
	EQUB    &00
	EQUS	"USB Support"
	EQUB	&00
	
.ROMVersion
	EQUS	"0.01 (28 May 2018)"
	
.copyright
	EQUB	&00
	EQUS	"(C)J.G.Harston"
	EQUB	&00

.Service
	PHA						\ Save service number
	CMP		#&04
	BNE		not4
	JMP		ServCmd04		\ *command
	
.not4
	CMP		#&09
	BNE		not9
	JMP		ServCmd09		\ *help
	
.not9
	CMP		#&28
	BNE		not28
	JMP		ServCmd28		\ *configure
	
.not28
	CMP		#&29
	BNE		not29
	JMP		ServCmd29		\ *status
	
.not29
	PLA
	RTS

.ServCmd04
.ServCmd09
	LSR		A				\ Convert service call number to bitmap
	
.ServCmd28
.ServCmd29
	PHA
	
\ 04 -> 02 -> 02 command   xxxx0010
\ 09 -> 04 -> 04 help      xxxx0100
\ 28 -> 28 -> 08 config    xxxx1000
\ 29 -> 29 -> 09 status    xxxx1001

	LDX		#0				\ Point to start of table
	STX		&F5				\ And set command number 0
	LDA		(&F2),Y			\ Get first character
	CMP		#&0D
	BEQ		ServCmdNull		\ *help<cr>, *status<cr>, *configure<cr>
	CMP		#&2E
	BEQ		ServCmdNull			\ *help .    *status .    *configure .

.ServCmdEntryLp
	INC		&F5				\ Increment command number
	PLA
	PHA						\ Get search type bitmap
	AND		CmdTable,X
	BEQ		ServCmdSkip		\ Don't match for this call
	INX						\ Point to start of command string
	TYA
	PHA						\ Save line pointer

.ServCmdCharLp
	LDA		(&F2),Y
	CMP		#&2E			\ ASC"."
	BEQ		ServCmdDot		\ Abbreviation
	AND		#&5F			\ Force to upper case
	CMP		CmdTable,X
	BNE 	ServCmdNext		\ No match, skip to next command
	INX
	INY						\ Step to next characters
	LDA		CmdTable,X
	BPL		ServCmdCharLp	\ Not end of table entry, loop back
	LDA		(&F2),Y
	CMP		#&41			\ ASC"A"	
	BCC		ServCmdMatch	\ End of command string, command matches
	
.ServCmdNext
	PLA
	TAY						\ Restore line pointer
	DEX						\ In case we are pointing to last+1 character
	
.ServCmdSkip
	INX
	LDA 	CmdTable,X
	BPL 	ServCmdSkip		\ Step to next entry
	AND 	#&0F
	BNE		ServCmdEntryLp	\ Not at end, check next entry
	PLA						\ Drop command type
	PLA
	RTS						\ Restore and return unclaimed

.ServCmdDot
.ServCmdSkipSpc
	INY						\ Step past dot

.ServCmdMatch
	LDA		(&F2),Y
	CMP		#&20           \ ASC" "
	BEQ		ServCmdSkipSpc 	\ And step past any spaces
	PLA						\ Drop old line pointer
	TSX
	LDA		#0
	STA		&102,X			\ Claim this call
	
.ServCmdNull
	LDA		&F5
	ASL A
	TAX						\ X=command offset, Carry Clear
	
.ServCmdDispatch
	LDA		CmdDispatch+1,X
	STA		&F7
	LDA		CmdDispatch+0,X
	STA		&F6
	PLA
	TAX
	EOR		#&01
	ADC		#&D8
	CMP		#&01			\ Convert command type, CC=Status
	JSR JumpF6
	PLA
	RTS						\ Return claimed or unclaimed

\ On entry,
\ Flags set from A:
\  EQ = Status
\  PL = Status/Configure
\  MI = Help/Command
\ (&F2),Y=>command line
\ X=command type
\
.JumpF6
	JMP		(&F6)
	
.ServCallStatus
	PHA
	PHA
	CLC						\ Push command type onto stack
	JMP		ServCmdDispatch	\ Jump to call *Status routines

.cmdUSB						\ *Help USB
DEY

.cmdNull
	CPX		#&04
	BNE		cmdHelp
	JSR		OSNEWL

.cmdTitleLp
	LDA		ROMTitle-3,X
	BNE		cmdTitleOver
	LDA		#&20			\ ASC" "
.cmdTitleOver
	CMP		#&28			\ ASC"("
	BEQ		cmdTitleDone	\ Print ROM title
	JSR		OSWRCH
	INX
	BNE		cmdTitleLp
	
.cmdTitleDone
	JSR		OSNEWL
	LDX		#&02			\ X=2 - list commands
	LDA		(&F2),Y
	CMP		#&0D
	BNE		cmdHelp
	RTS						\ No parameter, only display ROM title
	
.cmdHelp
	TYA
	PHA
	TXA
	PHA						\ Save Y=lineptr, X=command bitmap
	LDX		#&00
	LDY		#&00			\ Point to start of tables
	
.cmdHelpLp1
	INY
	INY						\ Step to next dispatch entry
	PLA
	PHA						\ Get search type bitmap
	AND		CmdTable,X
	BEQ		cmdHelpSkip		\ Don't match for this call
	AND		#&02
	BEQ		cmdHelpLp2
	JSR		Pr2Spaces		\ Indent *Help list
	
.cmdHelpLp2
	LDA		CmdTable+1,X
	BMI		cmdHelpInfo
	JSR		OSWRCH
	INX
	BNE		cmdHelpLp2

.cmdHelpInfo
	TXA
	PHA
	TYA
	PHA						\ Save table index and command number
	TSX
	LDA		&103,X
	AND		#&02
	ASL		A				\ Align syntax strings
	ADC		&308
	ADC		#&0A
	SBC		&318
	TAX
	
.cmdHelpSpace
	JSR		PrSpace
	DEX
	BNE		cmdHelpSpace
	TSX
	TXA
	TAY
	LDA		&103,Y			\ Command type
	LDX		&101,Y			\ Dispatch table index
	LDY		#&00
	JSR		ServCallStatus	\ Call dispatcher to display info
	PLA
	TAY
	PLA
	TAX						\ Get command number and index back
	DEX
	
.cmdHelpSkip
.cmdHelpSkipLp
	INX
	LDA		CmdTable,X
	BPL		cmdHelpSkipLp	\ Step to next entry
	AND		#&0F
	BNE		cmdHelpLp1		\ Not at end, check next entry
	PLA
	PLA
	TAY
	RTS

.CmdTable
	EQUB	&84
	EQUS	"USB"			\ hlp
	EQUB	&82
	EQUS	"USBDEVICES"	\     cmd
	EQUB	&8B
	EQUS	"USBKBD"		\     cmd cfg sta
	EQUB	&8B
	EQUS	"USBMOUSE"		\     cmd cfg sta
	EQUB	&8B
	EQUS	"USBPRINT"		\     cmd cfg sta
	EQUB	&82
	EQUS	"USBSTATUS"		\     cmd
	EQUB	&80

.CmdDispatch
	EQUW	cmdNull			\ <cr> or .
	EQUW	cmdUSB			\ USB
	EQUW	cmdDevices		\ USBDEVICES
	EQUW	cmdKBD			\ USBKBD
	EQUW	cmdMouse		\ USBMOUSE
	EQUW	cmdPrint		\ USBPRINT
	EQUW	cmdStatus		\ USBSTATUS

.cmdPrint
	LDX #128
	BNE cmdDoIt

.cmdMouse
	LDX #64
	BNE cmdDoIt

.cmdKBD
	LDX #63

.cmdDoIt
	BCC		cmdStatus2		\ *Status <command>
	PHA:
	TYA
	BEQ		cmdSyntax		\ Y=0, *help or *config. syntax requested
	LDA		(&F2),Y			\ Save command type, get char from line
	CMP		#&0D
	BEQ		cmdStatus1		\ *command<cr> or *configure command<cr>
	JSR		ScanOnOffName	\ Parse parameter OFF|ON|<num> to Y
	PLA
	BMI		cmdJump			\ *command <param>

							\ *Configure <word> <param>
	TYA
	PHA						\ Save <param>
	TXA
	EOR #&FF
	PHA						\ Mask to keep old bits
	JSR		CMOSRead
	TSX						\ Get my CMOS byte
	EOR		&102,X
	AND		&101,X			\ Merge new setting into byte
	EOR		&102,X
	TAY
	PLA
	PLA						\ Drop stacked bytes

.CMOSWrite					\ Write my CMOS byte
	LDX		#&13
	LDA		#&A2
	JMP		OSBYTE

.CMOSRead					\ Read my CMOS byte
	CLC

.CMOSRead1
:\LDA &23D:\AND #&C0:\EOR #&80 :\ If keyboard not claimed, use 0
:\TAY:\BEQ P%+5                :\ else use current setting
	LDY		&23C
	BCS		CMOSRead2		\ If CS or no CMOS, use current setting
	LDX		#&13
	LDA		#&A1
	JSR OSBYTE

.CMOSRead2
	TYA
	RTS

.cmdJump
	TXA
	ASL		A
	BCC		P%+5
	JMP		usbPRINT
	BPL		P%+5
	JMP		usbMOUSE
	JMP		usbKBD

.cmdSyntax
	PLA
	CPX		#&40
	BCS		cmdSyntax2
	JSR		PrText
	EQUS	"OFF|<num>"
	EQUB	&0D
	EQUB	0
	RTS
	
.cmdSyntax2
	JSR		PrText
	EQUS	"OFF|ON"
	EQUB	&0D
	EQUB	&00
	RTS

.errBadConfigure
	JSR		MkError
	EQUB	&FE
	EQUS	"Bad command"
	BRK

.cmdStatus1					\ *command<cr> or *configure command<cr>
	PLA
	BPL		errBadConfigure	\ *configure command<cr>
	
.cmdStatus2					\ *Status <command>
	TXA
	PHA						\ Save parameter bitmap
	JSR		CMOSRead1
	TSX						\ Get CMOS or current setting
	AND		&101,X
	TAY
	PLA						\ Y=value, A=mask
	CMP		#&40
	BCS		PrOnOffEtc		\ mask=64 or 128, OFF/ON
	TYA
	JSR PrDec
	JSR PrSpace				\ Print decimal value
	
.PrOnOffEtc
	TYA
	LDX		#&FF			\ Look for matching entry

.PrOnOffLp1
	INX
	CMP		txtNames,X
	BEQ		PrOnOffLp2		\ Matched entry prefix
	LDY		txtNames,X
	BPL		PrOnOffLp1		\ End of table
	
.PrOnOffDone
	JMP		OSNEWL
	
.PrOnOffLp2
	LDA		txtNames+1,X
	AND		#&7F
	CMP		#&41			\ ASC"A"
	BCC		PrOnOffDone
	JSR		OSWRCH
	INX
	BNE		PrOnOffLp2

.txtNames
	EQUB	0
	EQUS	"OFF"
	EQUB	1
	EQUS	"UK"
	EQUB 	2
	EQUS	"BBC"
	EQUB 	32
	EQUS	"Japan"
	EQUB	48
	EQUS	"USA"
	EQUB	64
	EQUS	"ON"
	EQUB	128
	EQUS	"ON"
	EQUB	0

:
.cmdDevices					\ USBDEVICES
	DEX

.cmdStatus					\ USBSTATUS
	TYA
	BNE		x
	JMP		OSNEWL

.usbKBD						\ USBKBD <num>
.usbMOUSE					\ USBMOUSE ON|OFF
.usbPRINT					\ USBPRINT ON|OFF

.x
	JSR		PrHex
	JSR		PrSpace			\ debug, command type
	TXA
	JSR		PrHex
	JSR		PrSpace			\ debug, command number
	TYA
	JSR		PrHex
	JMP		OSNEWL			\ debug, line pointer

\ (&F2),Y=> OFF|<dec>|OFF
\ Returns Y=0 | 0-255 | 255

.ScanOnOffName
	LDA		(&F2),Y
	AND		#&DF
	CMP		#&4F			\ ASC"O"
	BNE		ScanOnOffNum
	INY
	LDA		(&F2),Y
	AND		#&DF
	LDY		#&00
	CMP		#&46			\ ASC"F"
	BEQ		ScanOnOffDone
	DEY
	CMP		#&4E			\ ASC"N"
	BEQ		ScanOnOffDone
	JMP		errBadNumber

.ScanOnOffNum
	JSR		ScanDec
	TAY

.ScanOnOffDone
	RTS

.PrDec
	TAX
	LDA		#&99			\ Move value to X, start at -1 in BCD
	SED						\ Switch to decimal arithmetic

.PrDecLp
	CLC
	ADC		#&01			\ Add one in BCD mode
	DEX
	BPL		PrDecLp			\ Loop for all of source number
	CLD						\ Switch back to binary arithmetic
	CMP		#&0A
	BCC		PrNyb			\ If <10, print single digit
\ Fall through into PrHex

.PrHex
	PHA
	LSR		A
	LSR		A
	LSR		A
	LSR		A
	JSR		PrNyb
	PLA

.PrNyb
	AND		#&0F
	CMP		#&0A
	BCC		PrDig
	ADC		#&06

.PrDig
	ADC		#&30			\ ASC"0"
	JMP		OSWRCH

.PrText
	PLA
	STA		&F6
	PLA
	STA		&F7				\ Pop address after JSR
	TYA
	PHA						\ Save Y
	LDA		#&FF
	BNE		PrTextNext		\ Jump into loop
	
.PrTextLp
	LDY		#&00
	LDA		(&F6),Y			\ Get character
	BEQ		PrTextNext
	JSR		OSASCI			\ Print if not zero

.PrTextNext
	INC		&F6
	BNE		PrTextOver
	INC		&F7				\ Update address
.PrTextOver
	TAY
	BNE		PrTextLp		\ Loop back if not &00
	PLA
	TAY
	LDA		#&00
	JMP		(&F6)			\ Restore Y and return to code

.Pr2Spaces
	JSR		PrSpace

.PrSpace
	LDA		#&20			\ ASC" "
	JMP		OSWRCH:

.ScanDec
	JSR		ScanChkDigit	\ Get current digit
	BCS		ScanDecExit		\ Nothing to scan

.ScanDecLp
	STA		&F5				\ Store as current number
	JSR		ScanChkDigit	\ Get current digit
	BCS		ScanDecDone		\ No more digits
	PHA
	LDA		&F5				\ Save current digit
	CMP		#&1A
	BCS		ScanDecTooBig	\ If num>25, will overflow
	ASL		A
	ASL		A
	ADC		&F5
	ASL		A				\ num=num*10
	STA		&F5
	PLA						\ Get current digit back
	ADC		&F5
	BCC		ScanDecLp		\ num=num*10+digit

.ScanDecTooBig
.errBadNumber
	JSR		MkError
	EQUB	&FC
	EQUS	"Bad number"
	BRK

.ScanDecDone
	LDA		&F5
	CLC						\ CC=valid number scanned

.ScanDecExit				\ CS=bad number or digit
	RTS

.ScanChkDigit
	LDA		(&F2),Y			\ Get current character
	CMP		#&30			\ ASC"0"
	BCC		ScanDecErr		\ <'0'
	CMP		#&39+1			\ ASC"9"+1
	BCS		ScanDecErr		\ >'9'
	INY
	AND		#&0F
	RTS						\ Convert character to binary

.ScanDecErr
	SEC
	RTS						\ CS=invalid digit

.MkError
	PLA
	STA		&FD
	PLA
	STA		&FE				\ Pop address after JSR
	LDY		#&00			\ Index into the error block

.MkErrorLp
	INY
	LDA		(&FD),Y
	STA		&100,Y			\ Copy error block to stack
	BNE		MkErrorLp		\ Loop until terminating &00 byte
	STA		&100
	JMP		&100			\ Store &00 as BRK and jump to it

.RelocTable
SAVE "ROMCMD.rom", &8000, RelocTable