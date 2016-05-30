--- FUNCTION SOURCE (lenOf) id{0,0} ---
(v) {
  // We are going to deoptimize here when we call
  // loop the second time because hidden class of
  // v2 does not match hidden class of v.
  // We changed by adding a new property "name" to
  // the object allocated with Vec2.
  return v.len();
}

--- END ---
--- FUNCTION SOURCE (Vec2.len) id{0,1} ---
() {
    return Math.sqrt(this.len2());
  }

--- END ---
INLINE (Vec2.len) id{0,1} AS 1 AT <0:247>
--- FUNCTION SOURCE (Vec2.len2) id{0,2} ---
() {
    return this.x * this.x + this.y * this.y;
  },
--- END ---
INLINE (Vec2.len2) id{0,2} AS 2 AT <1:31>
--- Raw source ---
(v) {
  // We are going to deoptimize here when we call
  // loop the second time because hidden class of
  // v2 does not match hidden class of v.
  // We changed by adding a new property "name" to
  // the object allocated with Vec2.
  return v.len();
}


--- Optimized code ---
optimization_id = 0
source_position = 223
kind = OPTIMIZED_FUNCTION
name = lenOf
stack_slots = 2
Instructions (size = 224)
0x404513a0     0  55             push ebp
0x404513a1     1  89e5           mov ebp,esp
0x404513a3     3  56             push esi
0x404513a4     4  57             push edi
0x404513a5     5  83ec08         sub esp,0x8
                  ;;; Store dynamic frame alignment tag for spilled doubles
0x404513a8     8  c745f400000000 mov [ebp-0xc],0x0
                  ;;; <@0,#0> -------------------- B0 --------------------
                  ;;; <@2,#1> context
0x404513af    15  8b45fc         mov eax,[ebp-0x4]           ;; debug: position 223
                  ;;; <@3,#1> gap
0x404513b2    18  8945f0         mov [ebp-0x10],eax
                  ;;; <@10,#8> -------------------- B1 --------------------
                  ;;; <@11,#8> gap
0x404513b5    21  89c6           mov esi,eax
                  ;;; <@12,#10> stack-check
0x404513b7    23  3b2580b82d01   cmp esp,[0x12db880]
0x404513bd    29  7305           jnc 36  (0x404513c4)
0x404513bf    31  e85c11feff     call StackCheck  (0x40432520)    ;; code: BUILTIN
                  ;;; <@14,#10> lazy-bailout
                  ;;; <@15,#10> gap
0x404513c4    36  8b4508         mov eax,[ebp+0x8]
                  ;;; <@16,#12> check-non-smi
0x404513c7    39  a801           test al,0x1                 ;; debug: position 468
0x404513c9    41  0f8484000000   jz 179  (0x40451453)
                  ;;; <@18,#13> check-maps
0x404513cf    47  8178ff01f1004c cmp [eax-0x1],0x4c00f101    ;; object: 0x4c00f101 <Map(elements=3)>
0x404513d6    54  0f857c000000   jnz 184  (0x40451458)
                  ;;; <@20,#15> check-maps
                  ;;; <@22,#22> check-maps
                  ;;; <@24,#35> load-named-field
0x404513dc    60  8b480b         mov ecx,[eax+0xb]           ;; debug: position 178
                                                             ;; debug: position 109
                  ;;; <@26,#36> load-named-field
0x404513df    63  f20f104903     movsd xmm1,[ecx+0x3]
                  ;;; <@27,#36> gap
0x404513e4    68  0f28d1         movaps xmm2,xmm1
                  ;;; <@28,#41> mul-d
0x404513e7    71  f20f59d1       mulsd xmm2,xmm1             ;; debug: position 112
                  ;;; <@30,#45> load-named-field
0x404513eb    75  8b400f         mov eax,[eax+0xf]           ;; debug: position 127
                  ;;; <@32,#46> load-named-field
0x404513ee    78  f20f104803     movsd xmm1,[eax+0x3]
                  ;;; <@33,#46> gap
0x404513f3    83  0f28d9         movaps xmm3,xmm1
                  ;;; <@34,#51> mul-d
0x404513f6    86  f20f59d9       mulsd xmm3,xmm1             ;; debug: position 130
                  ;;; <@36,#53> add-d
0x404513fa    90  f20f58da       addsd xmm3,xmm2             ;; debug: position 121
                  ;;; <@40,#58> -------------------- B2 --------------------
                  ;;; <@42,#59> math-sqrt
0x404513fe    94  f20f51cb       sqrtsd xmm1,xmm3            ;; debug: position 193
                  ;;; <@46,#63> -------------------- B3 --------------------
                  ;;; <@48,#67> number-tag-d
0x40451402    98  8b0d207c2d01   mov ecx,[0x12d7c20]         ;; debug: position 470
0x40451408   104  89c8           mov eax,ecx
0x4045140a   106  83c00c         add eax,0xc
0x4045140d   109  0f8227000000   jc 154  (0x4045143a)
0x40451413   115  3b05247c2d01   cmp eax,[0x12d7c24]
0x40451419   121  0f871b000000   ja 154  (0x4045143a)
0x4045141f   127  8905207c2d01   mov [0x12d7c20],eax
0x40451425   133  41             inc ecx
0x40451426   134  c741ff7181004c mov [ecx-0x1],0x4c008171    ;; object: 0x4c008171 <Map(elements=3)>
0x4045142d   141  f20f114903     movsd [ecx+0x3],xmm1
                  ;;; <@49,#67> gap
0x40451432   146  89c8           mov eax,ecx
                  ;;; <@50,#65> return
0x40451434   148  89ec           mov esp,ebp
0x40451436   150  5d             pop ebp
0x40451437   151  c20800         ret 0x8
                  ;;; <@48,#67> -------------------- Deferred number-tag-d --------------------
0x4045143a   154  33c9           xor ecx,ecx
0x4045143c   156  60             pushad
0x4045143d   157  8b75fc         mov esi,[ebp-0x4]
0x40451440   160  33c0           xor eax,eax
0x40451442   162  bb00653800     mov ebx,0x386500
0x40451447   167  e8148dfbff     call 0x4040a160             ;; code: STUB, CEntryStub, minor: 1
0x4045144c   172  89442418       mov [esp+0x18],eax
0x40451450   176  61             popad
0x40451451   177  ebda           jmp 141  (0x4045142d)
                  ;;; -------------------- Jump table --------------------
                  ;;; deoptimize at <0:245> check-non-smi: Smi
0x40451453   179  e8b28bcbe2     call 0x2310a00a             ;; deoptimization bailout 1
                  ;;; deoptimize at <0:245> check-maps: wrong map
0x40451458   184  e8b78bcbe2     call 0x2310a014             ;; deoptimization bailout 2
0x4045145d   189  90             nop
0x4045145e   190  90             nop
0x4045145f   191  90             nop
0x40451460   192  90             nop
0x40451461   193  90             nop
0x40451462   194  66             nop
0x40451463   195  90             nop
                  ;;; Safepoint table.

Deoptimization Input Data (deopt points = 3)
 index  ast id    argc     pc
     0       3       0     36
     1       3       0     -1
     2       3       0     -1

Safepoints (size = 28)
0x404513c4    36  10 (sp -> fp)       0
0x4045144c   172  00 | ecx (sp -> fp)  <none>

RelocInfo (size = 289)
0x404513a8  comment  (;;; Store dynamic frame alignment tag for spilled doubles)
0x404513af  position  (223)
0x404513af  comment  (;;; <@0,#0> -------------------- B0 --------------------)
0x404513af  comment  (;;; <@2,#1> context)
0x404513b2  comment  (;;; <@3,#1> gap)
0x404513b5  comment  (;;; <@10,#8> -------------------- B1 --------------------)
0x404513b5  comment  (;;; <@11,#8> gap)
0x404513b7  comment  (;;; <@12,#10> stack-check)
0x404513c0  code target (BUILTIN)  (0x40432520)
0x404513c4  comment  (;;; <@14,#10> lazy-bailout)
0x404513c4  comment  (;;; <@15,#10> gap)
0x404513c7  comment  (;;; <@16,#12> check-non-smi)
0x404513c7  position  (468)
0x404513cf  comment  (;;; <@18,#13> check-maps)
0x404513d2  embedded object  (0x4c00f101 <Map(elements=3)>)
0x404513dc  comment  (;;; <@20,#15> check-maps)
0x404513dc  comment  (;;; <@22,#22> check-maps)
0x404513dc  position  (178)
0x404513dc  comment  (;;; <@24,#35> load-named-field)
0x404513dc  position  (109)
0x404513df  comment  (;;; <@26,#36> load-named-field)
0x404513e4  comment  (;;; <@27,#36> gap)
0x404513e7  comment  (;;; <@28,#41> mul-d)
0x404513e7  position  (112)
0x404513eb  comment  (;;; <@30,#45> load-named-field)
0x404513eb  position  (127)
0x404513ee  comment  (;;; <@32,#46> load-named-field)
0x404513f3  comment  (;;; <@33,#46> gap)
0x404513f6  comment  (;;; <@34,#51> mul-d)
0x404513f6  position  (130)
0x404513fa  comment  (;;; <@36,#53> add-d)
0x404513fa  position  (121)
0x404513fe  position  (193)
0x404513fe  comment  (;;; <@40,#58> -------------------- B2 --------------------)
0x404513fe  comment  (;;; <@42,#59> math-sqrt)
0x40451402  position  (470)
0x40451402  comment  (;;; <@46,#63> -------------------- B3 --------------------)
0x40451402  comment  (;;; <@48,#67> number-tag-d)
0x40451429  embedded object  (0x4c008171 <Map(elements=3)>)
0x40451432  comment  (;;; <@49,#67> gap)
0x40451434  comment  (;;; <@50,#65> return)
0x4045143a  comment  (;;; <@48,#67> -------------------- Deferred number-tag-d --------------------)
0x40451448  code target (STUB)  (0x4040a160)
0x40451453  comment  (;;; -------------------- Jump table --------------------)
0x40451453  comment  (;;; deoptimize at <0:245> check-non-smi: Smi)
0x40451454  runtime entry  (deoptimization bailout 1)
0x40451458  comment  (;;; deoptimize at <0:245> check-maps: wrong map)
0x40451459  runtime entry  (deoptimization bailout 2)
0x40451464  comment  (;;; Safepoint table.)

--- End code ---
[deoptimizing (DEOPT eager): begin 0x37d28f6d lenOf (opt #0) @2, FP to SP delta: 16]
            ;;; deoptimize at <0:245> check-maps: wrong map
  translating lenOf => node=3, height=0
    0xbfffedb4: [top + 20] <- 0x33208091 ; [sp + 28] 0x33208091 <undefined>
    0xbfffedb0: [top + 16] <- 0x460808e1 ; eax 0x460808e1 <a Vec2 with map 0x4c00f129>
    0xbfffedac: [top + 12] <- 0x40450446 ; caller's pc
    0xbfffeda8: [top + 8] <- 0xbfffedd0 ; caller's fp
    0xbfffeda4: [top + 4] <- 0x37d08081 ; [sp + 0] 0x37d08081 <FixedArray[113]>
    0xbfffeda4: [top + 4] <- 0x37d08081; context
    0xbfffeda0: [top + 0] <- 0x37d28f6d; function
[deoptimizing (eager): end 0x37d28f6d lenOf @2 => node=3, pc=0x4045059b, state=NO_REGISTERS, alignment=no padding, took 0.039 ms]
--- FUNCTION SOURCE (lenOf) id{3,0} ---
(v) {
  // We are going to deoptimize here when we call
  // loop the second time because hidden class of
  // v2 does not match hidden class of v.
  // We changed by adding a new property "name" to
  // the object allocated with Vec2.
  return v.len();
}

--- END ---
--- Raw source ---
(v) {
  // We are going to deoptimize here when we call
  // loop the second time because hidden class of
  // v2 does not match hidden class of v.
  // We changed by adding a new property "name" to
  // the object allocated with Vec2.
  return v.len();
}


--- Optimized code ---
optimization_id = 3
source_position = 223
kind = OPTIMIZED_FUNCTION
name = lenOf
stack_slots = 2
Instructions (size = 132)
0x40452360     0  55             push ebp
0x40452361     1  89e5           mov ebp,esp
0x40452363     3  56             push esi
0x40452364     4  57             push edi
0x40452365     5  83ec08         sub esp,0x8
                  ;;; Store dynamic frame alignment tag for spilled doubles
0x40452368     8  c745f400000000 mov [ebp-0xc],0x0
                  ;;; <@0,#0> -------------------- B0 --------------------
                  ;;; <@2,#1> context
0x4045236f    15  8b45fc         mov eax,[ebp-0x4]           ;; debug: position 223
                  ;;; <@3,#1> gap
0x40452372    18  8945f0         mov [ebp-0x10],eax
                  ;;; <@10,#8> -------------------- B1 --------------------
                  ;;; <@11,#8> gap
0x40452375    21  89c6           mov esi,eax
                  ;;; <@12,#10> stack-check
0x40452377    23  3b2580b82d01   cmp esp,[0x12db880]
0x4045237d    29  7305           jnc 36  (0x40452384)
0x4045237f    31  e89c01feff     call StackCheck  (0x40432520)    ;; code: BUILTIN
                  ;;; <@14,#10> lazy-bailout
                  ;;; <@15,#10> gap
0x40452384    36  8b4508         mov eax,[ebp+0x8]
                  ;;; <@16,#12> check-non-smi
0x40452387    39  a801           test al,0x1                 ;; debug: position 468
0x40452389    41  0f8428000000   jz 87  (0x404523b7)
                  ;;; <@18,#13> check-maps
0x4045238f    47  8178ff01f1004c cmp [eax-0x1],0x4c00f101    ;; object: 0x4c00f101 <Map(elements=3)>
0x40452396    54  740d           jz 69  (0x404523a5)
0x40452398    56  8178ff29f1004c cmp [eax-0x1],0x4c00f129    ;; object: 0x4c00f129 <Map(elements=3)>
0x4045239f    63  0f8517000000   jnz 92  (0x404523bc)
                  ;;; <@20,#15> check-maps
                  ;;; <@22,#18> push-argument
0x404523a5    69  50             push eax                    ;; debug: position 470
                  ;;; <@24,#17> constant-t
0x404523a6    70  bf1190d237     mov edi,0x37d29011          ;; object: 0x37d29011 <JS Function Vec2.len (SharedFunctionInfo 0x37d28e29)>
                  ;;; <@26,#19> call-js-function
0x404523ab    75  8b7717         mov esi,[edi+0x17]
0x404523ae    78  ff570b         call [edi+0xb]
                  ;;; <@28,#20> lazy-bailout
                  ;;; <@30,#22> return
0x404523b1    81  89ec           mov esp,ebp
0x404523b3    83  5d             pop ebp
0x404523b4    84  c20800         ret 0x8
                  ;;; -------------------- Jump table --------------------
                  ;;; deoptimize at <0:245> check-non-smi: Smi
0x404523b7    87  e84e7ccbe2     call 0x2310a00a             ;; deoptimization bailout 1
                  ;;; deoptimize at <0:245> check-maps: wrong map
0x404523bc    92  e8537ccbe2     call 0x2310a014             ;; deoptimization bailout 2
0x404523c1    97  90             nop
0x404523c2    98  90             nop
0x404523c3    99  90             nop
0x404523c4   100  90             nop
0x404523c5   101  90             nop
0x404523c6   102  66             nop
0x404523c7   103  90             nop
                  ;;; Safepoint table.

Deoptimization Input Data (deopt points = 4)
 index  ast id    argc     pc
     0       3       0     36
     1       3       0     -1
     2       3       0     -1
     3       4       0     81

Safepoints (size = 28)
0x40452384    36  10 (sp -> fp)       0
0x404523b1    81  10 (sp -> fp)       3

RelocInfo (size = 171)
0x40452368  comment  (;;; Store dynamic frame alignment tag for spilled doubles)
0x4045236f  position  (223)
0x4045236f  comment  (;;; <@0,#0> -------------------- B0 --------------------)
0x4045236f  comment  (;;; <@2,#1> context)
0x40452372  comment  (;;; <@3,#1> gap)
0x40452375  comment  (;;; <@10,#8> -------------------- B1 --------------------)
0x40452375  comment  (;;; <@11,#8> gap)
0x40452377  comment  (;;; <@12,#10> stack-check)
0x40452380  code target (BUILTIN)  (0x40432520)
0x40452384  comment  (;;; <@14,#10> lazy-bailout)
0x40452384  comment  (;;; <@15,#10> gap)
0x40452387  comment  (;;; <@16,#12> check-non-smi)
0x40452387  position  (468)
0x4045238f  comment  (;;; <@18,#13> check-maps)
0x40452392  embedded object  (0x4c00f101 <Map(elements=3)>)
0x4045239b  embedded object  (0x4c00f129 <Map(elements=3)>)
0x404523a5  comment  (;;; <@20,#15> check-maps)
0x404523a5  comment  (;;; <@22,#18> push-argument)
0x404523a5  position  (470)
0x404523a6  comment  (;;; <@24,#17> constant-t)
0x404523a7  embedded object  (0x37d29011 <JS Function Vec2.len (SharedFunctionInfo 0x37d28e29)>)
0x404523ab  comment  (;;; <@26,#19> call-js-function)
0x404523b1  comment  (;;; <@28,#20> lazy-bailout)
0x404523b1  comment  (;;; <@30,#22> return)
0x404523b7  comment  (;;; -------------------- Jump table --------------------)
0x404523b7  comment  (;;; deoptimize at <0:245> check-non-smi: Smi)
0x404523b8  runtime entry  (deoptimization bailout 1)
0x404523bc  comment  (;;; deoptimize at <0:245> check-maps: wrong map)
0x404523bd  runtime entry  (deoptimization bailout 2)
0x404523c8  comment  (;;; Safepoint table.)

--- End code ---
