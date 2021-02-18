.386
.model flat, stdcall
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;includem biblioteci, si declaram ce functii vrem sa importam
includelib msvcrt.lib
extern exit: proc
extern malloc: proc
extern memset: proc
extern printf: proc

includelib canvas.lib
extern BeginDrawing: proc
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;declaram simbolul start ca public - de acolo incepe executia
public start
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;sectiunile programului, date, respectiv cod
.data

;matrix[]=3 =>are bomba dar se deseneaza patratul
;matrix[]=2 =>are flag peste patrat
;matrix[]=1 =>se deseneaza doar patrat
;matrix[]=0 =>nu se afiseaza patratul si doar numarul de bombe din jur

matrix	   DB 10 dup(1)
		   DB 10 dup(1)
		   DB 10 dup(1)
		   DB 10 dup(1)
		   DB 10 dup(1)
		   DB 10 dup(1)
		   DB 10 dup(1)
		   DB 10 dup(1)
		   DB 10 dup(1)
		   DB 10 dup(1)
		           
matrix_no  DB 10 dup(0)
           DB 10 dup(0)
           DB 10 dup(0)
           DB 10 dup(0)
           DB 10 dup(0)
           DB 10 dup(0)
           DB 10 dup(0)
           DB 10 dup(0)
           DB 10 dup(0)
           DB 10 dup(0)
		   
my_aux DB 0
		   
symbol_width EQU 10
symbol_height EQU 20
include digits.inc
include letters.inc

arg1 EQU 8
arg2 EQU 12
arg3 EQU 16
arg4 EQU 20

counter DD 0 ; numara evenimentele de tip timer
bombs_left DB 90
pierdere DB 0

window_title DB "Minesweeper",0
area_width EQU 640
area_height EQU 480
area DD 0		

x1 DD 0
x2 DD 0
y1 DD 0
y2 DD 0 

 		   
.code
; procedura make_text afiseaza o litera sau o cifra la coordonatele date
; arg1 - simbolul de afisat (litera sau cifra)
; arg2 - pointer la vectorul de pixeli
; arg3 - pos_x
; arg4 - pos_y
make_text proc
	push ebp
	mov ebp, esp
	pusha
	
	mov eax, [ebp+arg1] ; citim simbolul de afisat
	cmp eax, 'A'
	jl make_digit
	cmp eax, 'Z'
	jg make_digit
	sub eax, 'A'
	lea esi, letters
	jmp draw_text
make_digit:
	cmp eax, '0'
	jl make_space
	cmp eax, '9'
	jg make_space
	sub eax, '0'
	lea esi, digits
	jmp draw_text
make_space:	
	mov eax, 26 ; de la 0 pana la 25 sunt litere, 26 e space
	lea esi, letters
	
draw_text:
	mov ebx, symbol_width
	mul ebx
	mov ebx, symbol_height
	mul ebx
	add esi, eax
	mov ecx, symbol_height
bucla_simbol_linii:
	mov edi, [ebp+arg2] ; pointer la matricea de pixeli
	mov eax, [ebp+arg4] ; pointer la coord y
	add eax, symbol_height
	sub eax, ecx
	mov ebx, area_width
	mul ebx
	add eax, [ebp+arg3] ; pointer la coord x
	shl eax, 2 ; inmultim cu 4, avem un DWORD per pixel
	add edi, eax
	push ecx
	mov ecx, symbol_width
bucla_simbol_coloane:
	cmp byte ptr [esi], 0
	je simbol_pixel_alb
	mov dword ptr [edi], 0
	jmp simbol_pixel_next
simbol_pixel_alb:
	mov dword ptr [edi], 0FFFFFFh
simbol_pixel_next:
	inc esi
	add edi, 4
	loop bucla_simbol_coloane
	pop ecx
	loop bucla_simbol_linii
	popa
	mov esp, ebp
	pop ebp
	ret
make_text endp

; un macro ca sa apelam mai usor desenarea simbolului
make_text_macro macro symbol, drawArea, x, y
	push y
	push x
	push drawArea
	push symbol
	call make_text
	add esp, 16
endm

make_schimbare_simbol macro click_x, click_y, abscisa_1, abscisa_2, ordonata_1, ordonata_2, i, j
	push j
	push i
	push ordonata_2
	push ordonata_1
	push abscisa_2
	push abscisa_1
	push click_y
	push click_x
	call schimbare_simbol
endm

schimbare_simbol proc	;([ebp+arg2], [ebp+arg3], x1,x2,y1,y2,i,j 
	;start
	push ebp
	mov ebp, esp
	pusha
	mov eax, [ebp+16]
	mov x1, eax
	mov eax, [ebp+20]
	mov x2, eax
	mov eax, [ebp+24]
	mov y1, eax
	mov eax, [ebp+28]	
    mov y2, eax
	mov ebx, [ebp+32]	
	mov eax, 10
	mul ebx
	mov ebx, eax		;i*10(i ala bun gen)
	mov ecx, [ebp+36]	;j
	
	mov eax, [ebp+8]	;arg2
	cmp eax, x1
	jb nope_0
	cmp eax,x2
	ja nope_0
	mov eax, [ebp+12]	;arg3
	cmp eax,y1
	jb nope_0
	cmp eax,y2
	ja nope_0
	
	cmp matrix_no[ebx][ecx], 'X'
	jne nu_bomba
	mov matrix[ebx][ecx], 3
	inc pierdere
	jmp nope_0
	nu_bomba:
	mov matrix[ebx][ecx], 0
	
	cmp bombs_left, 0
	je eticheta_last
	dec bombs_left
	eticheta_last:
	
	nope_0:
	popa
	mov esp, ebp
	pop ebp
	ret 32
	;end_start
schimbare_simbol endp


; functia de desenare - se apeleaza la fiecare click
; sau la fiecare interval de 200ms in care nu s-a dat click
; arg1 - evt (0 - initializare, 1 - click, 2 - s-a scurs intervalul fara click)
; arg2 - x
; arg3 - y
draw proc
	push ebp
	mov ebp, esp
	pusha
	
	mov eax, [ebp+arg1]
	cmp eax, 1
	jz evt_click
	cmp eax, 2
	jz evt_timer ; nu s-a efectuat click pe nimic
	;mai jos e codul care intializeaza fereastra cu pixeli albi
	mov eax, area_width
	mov ebx, area_height
	mul ebx
	shl eax, 2
	push eax
	push 255
	push area
	call memset
	add esp, 12
	jmp afisare_litere
	
evt_click:
	mov edi, area
	mov ecx, area_height
	mov ebx, [ebp+arg3]
	and ebx, 7
	inc ebx
	
	pusha
	mov ecx, 10
	un_loop_singuratic:
		
		mov edx, ecx
		mov ecx, 10
		alt_loop_singuratic:
			mov eax, 10
			push edx
			mul ecx
			pop edx
			add eax, 250
			mov ebx, eax
			
			mov eax, 20
			push edx
			mul edx
			pop edx
			add eax, 100
			mov esi, eax
			
			add ebx, 10
			mov x2, ebx
			sub ebx, 10
			add esi, 20
			mov y2, esi
			sub esi, 20
			
			dec ecx
			dec edx
			make_schimbare_simbol [ebp+arg2], [ebp+arg3], ebx, x2, esi, y2, edx, ecx ;;	([ebp+arg2], [ebp+arg3], x1,x2,y1,y2,i,j
			inc ecx
			inc edx
		loop alt_loop_singuratic
		mov ecx, edx
		
	loop un_loop_singuratic
	popa
	
bucla_linii:
	mov eax, [ebp+arg2]
	and eax, 0FFh
	; provide a new (random) color
	mul eax
	mul eax
	add eax, ecx
	push ecx
	mov ecx, area_width
bucla_coloane:
	mov [edi], eax
	add edi, 4
	add eax, ebx
	loop bucla_coloane
	pop ecx
	loop bucla_linii
	jmp afisare_litere
	
evt_timer:
	inc counter
	
afisare_litere:
	;afisam valoarea counter-ului curent (sute, zeci si unitati)
	mov ebx, 10
	mov eax, counter
	;cifra unitatilor
	mov edx, 0
	div ebx
	add edx, '0'
	make_text_macro edx, area, 30, 10
	;cifra zecilor
	mov edx, 0
	div ebx
	add edx, '0'
	make_text_macro edx, area, 20, 10
	;cifra sutelor
	mov edx, 0
	div ebx
	add edx, '0'
	make_text_macro edx, area, 10, 10
	
	;scriem un mesaj
	make_text_macro 'M', area, 255, 40
	make_text_macro 'I', area, 265, 40
	make_text_macro 'N', area, 275, 40
	make_text_macro 'E', area, 285, 40
	make_text_macro 'S', area, 295, 40
	make_text_macro 'W', area, 305, 40
	make_text_macro 'E', area, 315, 40
	make_text_macro 'E', area, 325, 40
	make_text_macro 'P', area, 335, 40
	make_text_macro 'E', area, 345, 40
	make_text_macro 'R', area, 355, 40
	
	;mesaj castigare
	cmp bombs_left, 0
	jne nu_inca
	make_text_macro 'S', area, 275, 60
	make_text_macro 'U', area, 285, 60
	make_text_macro 'C', area, 295, 60
	make_text_macro 'C', area, 305, 60
	make_text_macro 'E', area, 315, 60
	make_text_macro 'S', area, 325, 60
	make_text_macro 'S', area, 335, 60
	nu_inca:
	
	;mesaj pierdere
	cmp pierdere, 1
	jne nu_inca2
	make_text_macro 'F', area, 275, 60
	make_text_macro 'A', area, 285, 60
	make_text_macro 'I', area, 295, 60
	make_text_macro 'L', area, 305, 60
	make_text_macro 'U', area, 315, 60
	make_text_macro 'R', area, 325, 60
	make_text_macro 'E', area, 335, 60
	nu_inca2:
	
	
	;aici fac if-uri dupa valoare din matricea matrix ca sa vad ce afisez la fiecare pozitie din cele 100 de patrate pe care le foloseste tabla(ez, si dupa mai trb sa vad cu clickul)
	pusha
	mov ecx, 10
	un_loop:
		
		mov edx, ecx
		mov ecx, 10
		alt_loop:
			dec ecx
			dec edx
			push ecx
			push edx
			call draw_what
			inc ecx
			inc edx

			
			mov eax, 10
			push edx
			mul ecx
			pop edx
			add eax, 250
			mov ebx, eax
			
			mov eax, 20
			push edx
			mul edx
			pop edx
			add eax, 100
			mov esi, eax
			
			mov eax, 0
			mov al, my_aux
			
			
			make_text_macro	eax, area, ebx, esi
		loop alt_loop
		mov ecx, edx
		
	loop un_loop
	popa
	;make_text_macro 'Y', area, 370, 20	;flag
	;make_text_macro 'X', area, 380, 20 ;bmb

	
final_draw:
	popa 
	mov esp, ebp
	pop ebp
	ret
draw endp

draw_what proc ;(i,j)
	push ebp
	mov ebp, esp
	pusha
	mov eax, [ebp+8]	;i
	mov ebx, [ebp+12]	;j
	mov edx, 10;hereeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
	mul edx
	
	cmp matrix[eax][ebx], 2
	jne not_flag
	mov my_aux, 'Y'
	popa
	mov esp, ebp
	pop ebp
	ret	8
	jmp end_draw_what

	not_flag:
	cmp matrix[eax][ebx], 0
	jne not_number
	mov edx, 0
	mov dl, matrix_no[eax][ebx]
	add edx, '0'
	mov my_aux, dl
	popa
	mov esp, ebp
	pop ebp
	ret 8
	jmp end_draw_what
	
	;;added asdf
	not_number:
	cmp matrix[eax][ebx], 3
	jne not_bomb
	mov my_aux, 'X'
	popa
	mov esp, ebp
	pop ebp
	ret 8
	jmp end_draw_what
	
	not_bomb:
	mov my_aux, 'Z' 
	popa
	mov esp, ebp
	pop ebp
	ret 8	
	
	end_draw_what:
draw_what endp

bomb_generator proc
	push ebp
	mov ebp, esp
	
	mov matrix[0][0], 3
	mov matrix[0][5], 3
	mov matrix[20][8], 3
	mov matrix[30][0], 3
	mov matrix[40][1], 3
	mov matrix[50][7], 3
	mov matrix[60][9], 3
	mov matrix[70][9], 3
	mov matrix[80][3], 3
	mov matrix[90][2], 3

	mov esp, ebp
	pop ebp
	ret
bomb_generator endp

add_eax_if_3 proc
	push ebp
	mov ebp, esp
	
	mov ebx, [ebp+8]
	cmp ebx, 3
	jne done_add_eax_if_3
	inc eax
	jmp this_done
	done_add_eax_if_3:
	;cmp 

	this_done:
	mov esp, ebp
	pop ebp
	ret 4
add_eax_if_3 endp

add_eax_aux macro element
	mov ebx, 0
	mov bl, element
	push ebx
	call add_eax_if_3
endm

number_generator proc
	push ebp
	mov ebp, esp	
	
	mov ecx, 9
	f1:
		mov eax, ecx
		mov edx, 10
		mul edx
		mov edx, eax
		push ecx
		mov ecx, 9
		
		f2:
			mov eax, 0
			
			cmp matrix[edx][ecx], 3			;daca e bomba
			jne next_0
			mov eax, 'X'
			;mov matrix[edx][ecx], 1		;aici e treabaaaaaaaaaaaaaa
			jmp next_1
			next_0:
			
			cmp edx, 0
			je skip_0
			cmp ecx, 0
			je skip_0
			add_eax_aux matrix[edx-10][ecx-1]	;i-1, j-1
			skip_0:
			
			cmp edx, 90
			je skip_1
			cmp ecx, 9
			je skip_1
			add_eax_aux matrix[edx+10][ecx+1]	;i+1, j+1
			skip_1:
			
			cmp edx, 0
			je skip_2
			cmp ecx, 9
			je skip_2
			add_eax_aux matrix[edx-10][ecx+1]	;i-1, j+1
			skip_2:
			
			cmp edx, 90
			je skip_3
			cmp ecx, 0
			je skip_3
			add_eax_aux matrix[edx+10][ecx-1]	;i+1, j-1
			skip_3:
			
			cmp ecx, 0
			je skip_4
			add_eax_aux matrix[edx][ecx-1]		;i, j-1
			skip_4:
			
			cmp edx, 0
			je skip_5
			add_eax_aux matrix[edx-10][ecx]		;i-1, j
			skip_5:
			
			cmp edx, 90
			je skip_6
			add_eax_aux matrix[edx+10][ecx]		;i+1, j
			skip_6:
			
			cmp ecx, 9
			je skip_7
			add_eax_aux matrix[edx][ecx+1]		;i, j+1
			skip_7:
			
			next_1:
			;;aici pot face add eax, '0' ca sa am toate elementele matricii de tip char
			mov matrix_no[edx][ecx], al		;vedem cate bombe sunt in jurul patratului
			
			cmp ecx, 0
			je f2_done
			
			dec ecx
			jmp f2			
		f2_done:
		
		pop ecx
		cmp ecx, 0
		je f1_done
		
		dec ecx
		jmp f1
	f1_done:
	mov esp, ebp
	pop ebp
	ret
number_generator endp

start:
	call bomb_generator
	call number_generator
	mov matrix[0][0], 1
	mov matrix[0][5], 1
	mov matrix[20][8], 1
	mov matrix[30][0], 1
	mov matrix[40][1], 1
	mov matrix[50][7], 1
	mov matrix[60][9], 1
	mov matrix[70][9], 1
	mov matrix[80][3], 1
	mov matrix[90][2], 1
	
	;alocam memorie pentru zona de desenat
	mov eax, area_width
	mov ebx, area_height
	mul ebx
	shl eax, 2
	push eax
	call malloc
	add esp, 4
	mov area, eax
	;apelam functia de desenare a ferestrei
	; typedef void (*DrawFunc)(int evt, int x, int y);
	; void __cdecl BeginDrawing(const char *title, int width, int height, unsigned int *area, DrawFunc draw);
	push offset draw
	push area
	push area_height
	push area_width
	push offset window_title
	call BeginDrawing
	add esp, 20
	
	push 0
	call exit
end start
