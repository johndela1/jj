#!/usr/bin/csi -s

(use posix)
(use srfi-1)
(use srfi-18)
(use sdl-mixer)

(open-audio)
(define noise (load-sample "boom.vorbis"))


(define (make-ts l)
	(define (make-ts-iter l t)
		(cond
			((null? l) '())
			((eq? 0 (car l)) (make-ts-iter (cdr l) (add1 t)))
			(else (cons t (make-ts-iter (cdr l) (add1 t))))))
	(make-ts-iter l 0))

(define (start-at-zero l)
	(let ((offset (car l)))
		(map (lambda (x) (- x offset)) l)))

(define (scale l tot_time)
	(let ((factor  (/ tot_time (last l))))
		(map inexact->exact
			(map round
				(map (lambda (x) (* x factor)) l)))))
	
(define (pass? song input)
		(not (any (lambda (x) (> (abs x) 60))
			(map (lambda (pair) (- (car pair) (cadr pair)))
			     (zip song input)))))

(define (read-pattern n)
	(define (loop n acc)
		(cond
		((= n 0) (map inexact->exact (reverse acc)))
		(else
			(file-select '(0) '() 100)
			(let ((ts (current-milliseconds)))
				(read-byte)
				(loop (sub1 n) (cons ts acc))))))
	(loop n '()))

(define (align song input)
	(define (closest ts l smallest s_idx ret_idx)
		(cond
		((null? l) ret_idx)
		(else
			(if (< (abs (- (car l) ts)) smallest)
			(closest ts (cdr l) (abs (- (car l) ts))
				 (add1 s_idx) s_idx)
				
			(closest ts (cdr l) smallest
				 (add1 s_idx) ret_idx)))))
	(define (loop input idx)
		(cond
			((null? input) '())

			(else
			(let ((diff (- (closest (car input) song 1000 0 -1) idx)))
			(cond
				((= diff 0)
					(cons (car input)
					      (loop (cdr input) (add1 idx))))
				((> diff 0) (cons -99 (cons (car input)
					      (loop (cdr input) (+ 2 idx)))))
				((< diff 0)
					(if (null? (cdr input))
						(loop (cdr input) idx)
						(loop (cddr input) idx))))))))

	(loop input 0))
;(let ((good '(10 20 30 40 50 60)) (bad '(11 21 22 31 40 51 61 63)))
	;(print (align good bad)))
;(let ((good '(10 20 30 40 50 60)) (bad '(11 21 31 40  51 61)))
	;(print (align good bad)))
;(quit)

(define (count-strikes song)
	(define (loop song acc)
		(if (null? song)
			0
			(loop (cdr song) (add1 acc))))
	(loop song 0))

(define (play song)
	(if (null? song)
		't
		(begin
			(thread-sleep! (/ (car song) 500))
			(play-sample noise)
			(print 'XXXXXXXXX)
			(play (cdr song)))))
		
(define (ts->period song)
	(define (loop song prev_ts)
		(if (null? song)
			'()
			(let ((ts (car song)))
				(cons (- ts prev_ts) (loop (cdr song) ts)))))
	(loop song 0))

(define (diff song input)
	(if (or (null? song) (null? input))
		'()
		(cons (- (car song) (car input))
			(diff (cdr song) (cdr input)))))
(define s_fact 1000)
(define scaled-ts (compose (lambda (l) (scale l s_fact)) make-ts))
(define scaled-start-at-zero (compose (lambda (l) (scale l s_fact))
					start-at-zero))

(define (loop-song song n)
	(if (= n 0)
		'()
		(append song (loop-song song (sub1 n)))))

(define song (scaled-ts '(x 0 0 0 x 0 0 0 0 0 0 0 x 0 0 0)))
(define song (scaled-ts '(X 0 X X X 0)));two  over three
(define song (scaled-ts '(X 0 X 0 X X 0 X X 0 x 0)));two over three
(define song (scaled-ts '(x 0 x 0 x 0 x 0 0 x 0 x 0 x 0 x )))
(define song (scaled-ts '(B 0 B 0 B 0 0 B 0 B 0 0)));son
(define song (scaled-ts '(B 0 B 0 0 B 0 B 0 B 0 0)));rhumba
(define song (scaled-ts '(B b B 0 0 B b B)));war
(define song (scaled-ts '(B b B b b B b B)));war
(define song (scaled-ts '(B 0 B 0 b B 0 B 0 b 0 b)));bell pattern
(define song (scaled-ts
	(loop-song '(b b 0 b b 0 b 0 b b 0 b b 0 0 b) 2)));honky tonk cowbell
(define song (scaled-ts '(B 0 0 b b 0 0 B)));war

;(play (ts->period song))
(define (ts-main-loop)
	(let ((input (align song (scaled-start-at-zero
				  (read-pattern (length song))))))
		(print (pass? song input))
		(print (diff song input))
		(print (apply + (map abs (diff song input))))) (ts-main-loop))
(define (poll-keys)
  (if (null? (file-select '(0) '() 0))
        #f
	(begin
		(read-byte))))
		;#t)))

(define HZ 10)
(define (sampler n)
	(thread-sleep! (/ 1 HZ))
	(cond
		((= n 0) '())
		(else (cons (poll-keys) (sampler (sub1 n))))))

(define (play-digital samples)
	(thread-sleep! (/ 1 HZ))
	(cond
		((null? samples) 0)
		((car samples)(play-sample noise) (play-digital (cdr samples)))
		(else (play-digital (cdr samples)))))

(define (n-tup-of n v)
	(if (= n 0)
		'()
		(cons v (n-tup-of (sub1 n) v))))


(define (expand samples)
	(if (null? samples)
		'()
		(append (n-tup-of 10 (car samples)) (expand (cdr samples)))))

(define (foo samples n)
	(if (= n 0)
		samples
		(foo (cdr samples) (sub1 n))))


(define (smash samples)
	(cond
		((null? samples) '())
		((car samples) (print 'beat) (cons (car samples) (cdr samples)))
		(else (print 'nobeat) (smash (foo samples 10)))))
	

(define samples (reverse (sampler 20)))
(play-digital samples)
(print (smash (expand samples)))
