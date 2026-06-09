[TPHDFlyCam]
moduleMatches = 0x1A03E108, 0xA3175EEA

.origin = codecave

; Button codes after normalization:
;   ZR  = 0x00000004    ZL  = 0x00000080
;   R   = 0x00000200    L   = 0x00002000
;   R3  = 0x00010000    L3  = 0x00020000
; Enable combo: ZL|ZR|L3|R3 = 0x00030084

; Config from rules.txt
_cheat_enabled:
.byte $flycam

; Runtime state
_fc_active:
.byte 0

_fc_initialized:
.byte 0
.align 2

_fc_prev_buttons:
.int 0

_fc_speed:
.float 20.0

_fc_hcosYaw:
.float 0.0

_fc_hsinYaw:
.float 0.0

_fc_sinPitch:
.float 0.0

_fc_cosPitch:
.float 0.0

_fc_input_lock:
.int 0

_fc_saved_target_x:
.float 0.0

_fc_saved_target_y:
.float 0.0

_fc_saved_target_z:
.float 0.0

_fc_saved_pos_x:
.float 0.0

_fc_saved_pos_y:
.float 0.0

_fc_saved_pos_z:
.float 0.0

; Constants
_fc_four:
.float 4.0

_fc_0p98:
.float 0.98

_fc_neg0p98:
.float -0.98

_fc_cospitch_lim:
.float 0.199        ; sqrt(1 - 0.98^2), cosPitch forced here when sinPitch is clamped

_fc_three:
.float 3.0

_fc_half:
.float 0.5

_fc_one:
.float 1.0

_fc_zero:
.float 0.0

_fc_speedmult:
.float 2.0

_fc_maxspeed:
.float 200.0

_fc_minspeed:
.float 5.0

_fc_rotspeed:
.float 0.08

; fc_rsqrt
; Input: f0 = x. Output: f0 = 1/sqrt(x).
; Newton-Raphson refinement of frsqrte: e1 = 0.5 * e0 * (3 - x*e0^2)
; Clobbers f1-f4, r3. Leaf (no bl).
fc_rsqrt:
    frsqrte f1, f0
    fmuls   f2, f1, f1
    fmuls   f3, f0, f2
    lis     r3, _fc_three@ha
    lfs     f4, _fc_three@l(r3)
    lfs     f2, _fc_half@l(r3)
    fsubs   f3, f4, f3
    fmuls   f1, f1, f3
    fmuls   f0, f2, f1
    blr

; fc_get_input_base
; Output: r3 = controller input block, or 0.
; Resolves Pro as *(*(*_controller + 0x4) + 0x10) + 0x70.
; Resolves GamePad as *(*(*_controller + 0x4) + 0x10) + 0x0C.
; Clobbers r3-r4.
fc_get_input_base:
    lis   r3, _controller@ha
    lwz   r3, _controller@l(r3)
    cmpwi cr1, r3, 0
    beq   cr1, fc_get_input_base_return
    lwz   r3, +0x04(r3)
    cmpwi cr1, r3, 0
    beq   cr1, fc_get_input_base_return
    lis   r4, _controllerType@ha
    lbz   r4, _controllerType@l(r4)
    cmpwi cr1, r4, 1
    beq   cr1, fc_get_input_base_pro
    addi  r3, r3, 0x0C
    blr
fc_get_input_base_pro:
    lwz   r3, 0x10(r3)
    cmpwi cr1, r3, 0
    beq   cr1, fc_get_input_base_return
    addi  r3, r3, 0x70
fc_get_input_base_return:
    blr

; fc_button_mask
; Output: r3 = buttons & mask.
; Input: r3 = button state, r4 = button mask. Clobbers r3.
fc_button_mask:
    and   r3, r3, r4
    blr

; fc_normalize_buttons
; Input: r3 = raw button state. Output: r3 = Pro Controller button state.
; Clobbers r4-r5.
fc_normalize_buttons:
    lis   r4, _controllerType@ha
    lbz   r4, _controllerType@l(r4)
    cmpwi cr1, r4, 0
    bne   cr1, fc_normalize_buttons_return

    mr    r4, r3
    li    r3, 0

    ; A: GamePad 0x00008000 -> Pro 0x00000010
    andi. r5, r4, 0x8000
    beq   fc_norm_b
    ori   r3, r3, 0x0010
fc_norm_b:
    ; B: GamePad 0x00004000 -> Pro 0x00000040
    andi. r5, r4, 0x4000
    beq   fc_norm_x
    ori   r3, r3, 0x0040
fc_norm_x:
    ; X: GamePad 0x00002000 -> Pro 0x00000008
    andi. r5, r4, 0x2000
    beq   fc_norm_y
    ori   r3, r3, 0x0008
fc_norm_y:
    ; Y: GamePad 0x00001000 -> Pro 0x00000020
    andi. r5, r4, 0x1000
    beq   fc_norm_plus
    ori   r3, r3, 0x0020
fc_norm_plus:
    ; Plus: GamePad 0x00000008 -> Pro 0x00000400
    andi. r5, r4, 0x0008
    beq   fc_norm_minus
    ori   r3, r3, 0x0400
fc_norm_minus:
    ; Minus: GamePad 0x00000004 -> Pro 0x00001000
    andi. r5, r4, 0x0004
    beq   fc_norm_l3
    ori   r3, r3, 0x1000
fc_norm_l3:
    ; L3: GamePad 0x00040000 -> Pro 0x00020000
    andis. r5, r4, 0x0004
    beq   fc_norm_r3
    oris  r3, r3, 0x0002
fc_norm_r3:
    ; R3: GamePad 0x00020000 -> Pro 0x00010000
    andis. r5, r4, 0x0002
    beq   fc_norm_l
    oris  r3, r3, 0x0001
fc_norm_l:
    ; L: GamePad 0x00000020 -> Pro 0x00002000
    andi. r5, r4, 0x0020
    beq   fc_norm_zl
    ori   r3, r3, 0x2000
fc_norm_zl:
    ; ZL: GamePad 0x00000080 -> Pro 0x00000080
    andi. r5, r4, 0x0080
    beq   fc_norm_r
    ori   r3, r3, 0x0080
fc_norm_r:
    ; R: GamePad 0x00000010 -> Pro 0x00000200
    andi. r5, r4, 0x0010
    beq   fc_norm_zr
    ori   r3, r3, 0x0200
fc_norm_zr:
    ; ZR: GamePad 0x00000040 -> Pro 0x00000004
    andi. r5, r4, 0x0040
    beq   fc_norm_dup
    ori   r3, r3, 0x0004
fc_norm_dup:
    ; D-Up: GamePad 0x00000200 -> Pro 0x00000001
    andi. r5, r4, 0x0200
    beq   fc_norm_ddown
    ori   r3, r3, 0x0001
fc_norm_ddown:
    ; D-Down: GamePad 0x00000100 -> Pro 0x00004000
    andi. r5, r4, 0x0100
    beq   fc_norm_dleft
    ori   r3, r3, 0x4000
fc_norm_dleft:
    ; D-Left: GamePad 0x00000800 -> Pro 0x00000002
    andi. r5, r4, 0x0800
    beq   fc_norm_dright
    ori   r3, r3, 0x0002
fc_norm_dright:
    ; D-Right: GamePad 0x00000400 -> Pro 0x00008000
    andi. r5, r4, 0x0400
    beq   fc_normalize_buttons_return
    ori   r3, r3, 0x8000
fc_normalize_buttons_return:
    blr

; flycamlogic
; Hooked with bla at 0x028df758.
; Saves r3-r5, r14-r21, f14-f21, LR. Stack frame 0x80.
; Displaced instruction (lis r29, 0x1014) replicated before final blr.
flycamlogic:
    ; Prologue
    stwu  r1,  -0x80(r1)
    mflr  r14
    stw   r14, +0x08(r1)
    stw   r15, +0x0C(r1)
    stw   r16, +0x10(r1)
    stw   r17, +0x14(r1)
    stw   r18, +0x18(r1)
    stw   r19, +0x1C(r1)
    stw   r20, +0x20(r1)
    stw   r21, +0x24(r1)
    stw   r3,  +0x60(r1)
    stw   r4,  +0x64(r1)
    stw   r5,  +0x68(r1)
    stfs  f14, +0x30(r1)
    stfs  f15, +0x34(r1)
    stfs  f16, +0x38(r1)
    stfs  f17, +0x3C(r1)
    stfs  f18, +0x40(r1)
    stfs  f19, +0x44(r1)
    stfs  f20, +0x48(r1)
    stfs  f21, +0x4C(r1)

    ; Check cheat enabled
    lis   r14, _cheat_enabled@ha
    lbz   r15, _cheat_enabled@l(r14)
    cmpwi cr1, r15, 0
    beq   cr1, fc_end

    ; Read 32-bit buttons from the active controller input block
    bl    fc_get_input_base
    cmpwi cr1, r3, 0
    beq   cr1, fc_end
    mr    r15, r3
    lwz   r16, +0x00(r15)           ; r16 = current buttons
    mr    r3, r16
    bl    fc_normalize_buttons
    mr    r16, r3

    ; Ignore activation buttons until each one is released
    lis   r14, _fc_input_lock@ha
    lwz   r18, _fc_input_lock@l(r14)
    and   r18, r18, r16
    stw   r18, _fc_input_lock@l(r14)
    andc  r16, r16, r18

    ; Compute rising edges
    lis   r14, _fc_prev_buttons@ha
    lwz   r21, _fc_prev_buttons@l(r14)
    andc  r17, r16, r21             ; r17 = newly pressed (current & ~prev)
    stw   r16, _fc_prev_buttons@l(r14)

    ; Save stack scratch; fc_init clobbers r16/r17
    stw   r16, +0x54(r1)
    stw   r17, +0x58(r1)
    stw   r15, +0x5C(r1)

    ; Branch on active state
    lis   r14, _fc_active@ha
    lbz   r18, _fc_active@l(r14)
    cmpwi cr1, r18, 0
    beq   cr1, fc_inactive

    ; Active state

    ; Re-assert freeze flag every frame
    lis   r19, _freezeFlag@ha
    li    r18, 1
    stb   r18, _freezeFlag@l(r19)

    ; L3 rising edge (0x00020000): restore camera and exit
    mr    r3, r17
    lis   r4, 0x0002
    bl    fc_button_mask
    cmpwi cr1, r3, 0
    bne   cr1, fc_exit_restore_camera

    ; R3 rising edge (0x00010000): exit, Link to camera
    mr    r3, r17
    lis   r4, 0x0001
    bl    fc_button_mask
    cmpwi cr1, r3, 0
    bne   cr1, fc_exit_link_to_cam

    ; R rising edge (0x00000200): speed up
    mr    r3, r17
    li    r4, 0x0200
    bl    fc_button_mask
    cmpwi cr1, r3, 0
    beq   cr1, fc_no_speedup
    lis   r19, _fc_speed@ha
    lfs   f0, _fc_speed@l(r19)
    lis   r20, _fc_speedmult@ha
    lfs   f1, _fc_speedmult@l(r20)
    fmuls f0, f0, f1
    lis   r20, _fc_maxspeed@ha
    lfs   f1, _fc_maxspeed@l(r20)
    fcmpu cr2, f0, f1
    ble   cr2, fc_speedup_store
    fmr   f0, f1
fc_speedup_store:
    stfs  f0, _fc_speed@l(r19)
fc_no_speedup:

    ; L rising edge (0x00002000): speed down
    mr    r3, r17
    li    r4, 0x2000
    bl    fc_button_mask
    cmpwi cr1, r3, 0
    beq   cr1, fc_no_speeddown
    lis   r19, _fc_speed@ha
    lfs   f0, _fc_speed@l(r19)
    lis   r20, _fc_half@ha
    lfs   f1, _fc_half@l(r20)
    fmuls f0, f0, f1
    lis   r20, _fc_minspeed@ha
    lfs   f1, _fc_minspeed@l(r20)
    fcmpu cr2, f0, f1
    bge   cr2, fc_speeddown_store
    fmr   f0, f1
fc_speeddown_store:
    stfs  f0, _fc_speed@l(r19)
fc_no_speeddown:

    ; Check if direction state needs init
    lis   r14, _fc_initialized@ha
    lbz   r19, _fc_initialized@l(r14)
    cmpwi cr1, r19, 0
    beq   cr1, fc_init
    b     fc_move

fc_inactive:
    ; Check for ZL+ZR+L3+R3 combo with at least one rising edge
    lis   r20, 0x0003
    ori   r20, r20, 0x0084          ; r20 = 0x00030084 (combo mask)
    mr    r3, r16
    mr    r4, r20
    bl    fc_button_mask
    cmpw  cr1, r3, r20              ; all combo buttons held?
    bne   cr1, fc_end
    mr    r3, r17
    mr    r4, r20
    bl    fc_button_mask
    cmpwi cr2, r3, 0                ; at least one is a rising edge?
    beq   cr2, fc_end
    mr    r21, r20
    ; Save camera target and position for L3 restore
    lis   r19, _cameraPtr@ha
    lwz   r19, _cameraPtr@l(r19)
    cmpwi cr1, r19, 0
    beq   cr1, fc_end
    addi  r19, r19, 0x2AC
    lis   r20, _fc_saved_target_x@ha
    lfs   f0, +0x00(r19)
    stfs  f0, _fc_saved_target_x@l(r20)
    lfs   f0, +0x04(r19)
    stfs  f0, _fc_saved_target_y@l(r20)
    lfs   f0, +0x08(r19)
    stfs  f0, _fc_saved_target_z@l(r20)
    lfs   f0, +0x0C(r19)
    stfs  f0, _fc_saved_pos_x@l(r20)
    lfs   f0, +0x10(r19)
    stfs  f0, _fc_saved_pos_y@l(r20)
    lfs   f0, +0x14(r19)
    stfs  f0, _fc_saved_pos_z@l(r20)
    ; Lock the activation buttons until they are released
    lis   r14, _fc_input_lock@ha
    stw   r21, _fc_input_lock@l(r14)
    ; Activate freecam
    lis   r14, _fc_active@ha
    li    r18, 1
    stb   r18, _fc_active@l(r14)
    li    r18, 0
    stb   r18, _fc_initialized@l(r14)
    b     fc_end

fc_exit_restore_camera:
    ; Restore camera target and position, then exit
    lis   r20, _cameraPtr@ha
    lwz   r20, _cameraPtr@l(r20)
    cmpwi cr1, r20, 0
    beq   cr1, fc_deactivate
    addi  r20, r20, 0x2AC           ; r20 = camera base
    lis   r21, _fc_saved_target_x@ha
    lfs   f0, _fc_saved_target_x@l(r21)
    stfs  f0, +0x00(r20)
    lfs   f0, _fc_saved_target_y@l(r21)
    stfs  f0, +0x04(r20)
    lfs   f0, _fc_saved_target_z@l(r21)
    stfs  f0, +0x08(r20)
    lfs   f0, _fc_saved_pos_x@l(r21)
    stfs  f0, +0x0C(r20)
    lfs   f0, _fc_saved_pos_y@l(r21)
    stfs  f0, +0x10(r20)
    lfs   f0, _fc_saved_pos_z@l(r21)
    stfs  f0, +0x14(r20)
    b     fc_deactivate

fc_exit_link_to_cam:
    ; Teleport Link to current camera position, then exit
    lis   r20, _cameraPtr@ha
    lwz   r20, _cameraPtr@l(r20)
    addi  r20, r20, 0x2AC           ; r20 = camera base
    lis   r19, _linkPtr@ha
    lwz   r19, _linkPtr@l(r19)      ; r19 = Link base
    lfs   f0, +0x0C(r20)
    stfs  f0, +0x00(r19)            ; link.x = cam_pos.x
    lfs   f0, +0x10(r20)
    stfs  f0, +0x04(r19)            ; link.y = cam_pos.y
    lfs   f0, +0x14(r20)
    stfs  f0, +0x08(r19)            ; link.z = cam_pos.z
    b     fc_deactivate

fc_deactivate:
    lis   r14, _fc_active@ha
    li    r18, 0
    stb   r18, _fc_active@l(r14)
    stb   r18, _fc_initialized@l(r14)
    lis   r19, _freezeFlag@ha
    stb   r18, _freezeFlag@l(r19)
    stb   r18, _decoupleFlag@l(r19)
    lis   r19, _fc_input_lock@ha
    stw   r18, _fc_input_lock@l(r19)
    b     fc_end

fc_init:
    ; Set decouple flag
    lis   r19, _decoupleFlag@ha
    li    r18, 1
    stb   r18, _decoupleFlag@l(r19)

    ; Camera base: r20 = *_cameraPtr + 0x2AC
    lis   r20, _cameraPtr@ha
    lwz   r20, _cameraPtr@l(r20)
    addi  r20, r20, 0x2AC

    ; Load cam_pos and cam_target
    lfs   f14, +0x0C(r20)
    lfs   f15, +0x10(r20)
    lfs   f16, +0x14(r20)
    lfs   f17, +0x00(r20)
    lfs   f18, +0x04(r20)
    lfs   f19, +0x08(r20)

    ; dir = target - pos
    fsubs f17, f17, f14
    fsubs f18, f18, f15
    fsubs f19, f19, f16

    ; Normalize dir
    fmuls  f0, f17, f17
    fmadds f0, f18, f18, f0
    fmadds f0, f19, f19, f0
    bl     fc_rsqrt
    fmuls  f17, f17, f0
    fmuls  f18, f18, f0
    fmuls  f19, f19, f0

    ; f17=nx, f18=ny=sinPitch, f19=nz
    lis   r14, _fc_sinPitch@ha
    stfs  f18, _fc_sinPitch@l(r14)

    ; cosPitch = sqrt(nx^2 + nz^2) = (nx^2+nz^2) * rsqrt(nx^2+nz^2)
    fmuls  f0, f17, f17
    fmadds f0, f19, f19, f0
    fmr    f20, f0
    bl     fc_rsqrt
    fmuls  f20, f20, f0
    stfs   f20, _fc_cosPitch@l(r14)

    ; Guard: cosPitch ~= 0 (looking straight up/down); use default yaw
    lis   r15, _fc_zero@ha
    lfs   f21, _fc_zero@l(r15)
    fcmpu cr2, f20, f21
    beq   cr2, fc_init_default_yaw

    ; hcosYaw = nx / cosPitch, hsinYaw = nz / cosPitch
    fdivs f17, f17, f20
    fdivs f19, f19, f20
    stfs  f17, _fc_hcosYaw@l(r14)
    stfs  f19, _fc_hsinYaw@l(r14)
    b     fc_init_done

fc_init_default_yaw:
    lis   r15, _fc_one@ha
    lfs   f21, _fc_one@l(r15)
    stfs  f21, _fc_hcosYaw@l(r14)
    lfs   f21, _fc_zero@l(r15)
    stfs  f21, _fc_hsinYaw@l(r14)

fc_init_done:
    lis   r14, _fc_initialized@ha
    li    r16, 1
    stb   r16, _fc_initialized@l(r14)
    ; fall through to fc_move

fc_move:
    ; Reload buttons (fc_init clobbers r16)
    lwz   r16, +0x54(r1)

    ; Reload active input block (sticks are relative to same input block)
    lwz   r15, +0x5C(r1)

    ; Load sticks (floats, -1.0 to 1.0)
    lfs   f16, +0x0C(r15)   ; leftStickX  (strafe)
    lfs   f17, +0x10(r15)   ; leftStickY  (forward/back, verify sign in game)
    lfs   f18, +0x14(r15)   ; rightStickX (yaw)
    lfs   f19, +0x18(r15)   ; rightStickY (pitch)

    ; Correct axis directions (game reports these inverted)
    fneg  f16, f16
    fneg  f18, f18

    ; Mirror flag: if _mirrorFlag == 1, invert back
    lis   r18, _mirrorFlag@ha
    lbz   r19, _mirrorFlag@l(r18)
    cmpwi cr2, r19, 1
    bne   cr2, fc_no_mirror
    fneg  f16, f16
    fneg  f18, f18
fc_no_mirror:

    ; Load direction state
    lis   r17, _fc_hcosYaw@ha
    lfs   f0, _fc_hcosYaw@l(r17)
    lfs   f1, _fc_hsinYaw@l(r17)
    lfs   f2, _fc_sinPitch@l(r17)
    lfs   f3, _fc_cosPitch@l(r17)

    ; Vertical: ZR (0x4) = up, ZL (0x80) = down
    lis   r17, _fc_zero@ha
    lfs   f15, _fc_zero@l(r17)
    mr    r3, r16
    li    r4, 0x0004
    bl    fc_button_mask
    cmpwi cr1, r3, 0
    beq   cr1, fc_check_zl
    lis   r17, _fc_one@ha
    lfs   f15, _fc_one@l(r17)
    b     fc_vert_done
fc_check_zl:
    mr    r3, r16
    li    r4, 0x0080
    bl    fc_button_mask
    cmpwi cr1, r3, 0
    beq   cr1, fc_vert_done
    lis   r17, _fc_one@ha
    lfs   f15, _fc_one@l(r17)
    fneg  f15, f15
fc_vert_done:

    ; Load speed
    lis   r17, _fc_speed@ha
    lfs   f14, _fc_speed@l(r17)

    ; Movement deltas:
    ; dx = leftY * hcosYaw * cosPitch - leftX * hsinYaw
    fmuls   f4, f17, f0
    fmuls   f4, f4,  f3
    fnmsubs f4, f16, f1, f4

    ; dz = leftY * hsinYaw * cosPitch + leftX * hcosYaw
    fmuls   f5, f17, f1
    fmuls   f5, f5,  f3
    fmadds  f5, f16, f0, f5

    ; dy = leftY * sinPitch + vert
    fmadds  f6, f17, f2, f15

    ; Scale by speed
    fmuls f4, f4, f14
    fmuls f5, f5, f14
    fmuls f6, f6, f14

    ; Camera base: r20 = *_cameraPtr + 0x2AC
    lis   r20, _cameraPtr@ha
    lwz   r20, _cameraPtr@l(r20)
    addi  r20, r20, 0x2AC

    ; Update cam_pos
    lfs   f20, +0x0C(r20)
    fadds f20, f20, f4
    stfs  f20, +0x0C(r20)
    lfs   f20, +0x10(r20)
    fadds f20, f20, f6
    stfs  f20, +0x10(r20)
    lfs   f20, +0x14(r20)
    fadds f20, f20, f5
    stfs  f20, +0x14(r20)

    ; Update cam_target = cam_pos + fwd * 4
    lis   r21, _fc_four@ha
    lfs   f21, _fc_four@l(r21)
    fmuls f7, f0, f3
    fmuls f7, f7, f21
    fmuls f8, f1, f3
    fmuls f8, f8, f21
    fmuls f9, f2, f21
    lfs   f20, +0x0C(r20)
    fadds f20, f20, f7
    stfs  f20, +0x00(r20)
    lfs   f20, +0x10(r20)
    fadds f20, f20, f9
    stfs  f20, +0x04(r20)
    lfs   f20, +0x14(r20)
    fadds f20, f20, f8
    stfs  f20, +0x08(r20)

    ; Yaw rotation: delta = rightX * rot_speed
    lis   r17, _fc_rotspeed@ha
    lfs   f20, _fc_rotspeed@l(r17)
    fmuls f20, f18, f20
    fnmsubs f7, f20, f1, f0         ; new_hcosYaw = hcosYaw - delta*hsinYaw
    fmadds  f8, f20, f0, f1         ; new_hsinYaw = hsinYaw + delta*hcosYaw
    fmuls  f0, f7, f7
    fmadds f0, f8, f8, f0
    bl     fc_rsqrt
    fmuls  f7, f7, f0
    fmuls  f8, f8, f0

    ; Reload sinPitch/cosPitch; fc_rsqrt clobbered f2/f3
    lis   r17, _fc_sinPitch@ha
    lfs   f2, _fc_sinPitch@l(r17)
    lfs   f3, _fc_cosPitch@l(r17)

    ; Pitch rotation: delta = rightY * rot_speed
    lis   r17, _fc_rotspeed@ha
    lfs   f20, _fc_rotspeed@l(r17)
    fmuls f20, f19, f20
    fmadds  f9,  f20, f3, f2        ; new_sinPitch = sinPitch + delta*cosPitch
    fnmsubs f10, f20, f2, f3        ; new_cosPitch = cosPitch - delta*sinPitch

    ; Renorm pitch state
    fmuls  f0, f9, f9
    fmadds f0, f10, f10, f0
    bl     fc_rsqrt
    fmuls  f9,  f9,  f0
    fmuls  f10, f10, f0

    ; Clamp sinPitch to [-0.98, 0.98] AFTER renorm; force cosPitch to stay positive
    lis   r17, _fc_0p98@ha
    lfs   f11, _fc_0p98@l(r17)
    fcmpu cr2, f9, f11
    ble   cr2, fc_pitch_clamp_low
    fmr   f9,  f11
    lis   r17, _fc_cospitch_lim@ha
    lfs   f10, _fc_cospitch_lim@l(r17)
    b     fc_pitch_done
fc_pitch_clamp_low:
    lfs   f11, _fc_neg0p98@l(r17)
    fcmpu cr2, f9, f11
    bge   cr2, fc_pitch_done
    fmr   f9,  f11
    lis   r17, _fc_cospitch_lim@ha
    lfs   f10, _fc_cospitch_lim@l(r17)
fc_pitch_done:

    ; Store updated direction state
    lis   r17, _fc_hcosYaw@ha
    stfs  f7,  _fc_hcosYaw@l(r17)
    stfs  f8,  _fc_hsinYaw@l(r17)
    stfs  f9,  _fc_sinPitch@l(r17)
    stfs  f10, _fc_cosPitch@l(r17)

fc_end:
    lfs   f14, +0x30(r1)
    lfs   f15, +0x34(r1)
    lfs   f16, +0x38(r1)
    lfs   f17, +0x3C(r1)
    lfs   f18, +0x40(r1)
    lfs   f19, +0x44(r1)
    lfs   f20, +0x48(r1)
    lfs   f21, +0x4C(r1)
    lwz   r14, +0x08(r1)
    mtlr  r14
    lwz   r15, +0x0C(r1)
    lwz   r16, +0x10(r1)
    lwz   r17, +0x14(r1)
    lwz   r18, +0x18(r1)
    lwz   r19, +0x1C(r1)
    lwz   r20, +0x20(r1)
    lwz   r21, +0x24(r1)
    lwz   r3,  +0x60(r1)
    lwz   r4,  +0x64(r1)
    lwz   r5,  +0x68(r1)
    addi  r1,  r1, 0x80
    lis   r29, 0x1014
    blr

; Address labels
0x028df758 = bla flycamlogic

0x1014b578 = _cameraPtr:
0x1017F640 = _linkPtr:
0x1014A795 = _freezeFlag:
0x1014A973 = _decoupleFlag:
0x1012667D = _mirrorFlag:
0x1012D554 = _controller:
0x1012d547 = _controllerType:
