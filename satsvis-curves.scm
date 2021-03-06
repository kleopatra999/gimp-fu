;; -*- mode: Gimp; -*-

;;; Usage:

;; $ gimp -d -f -i -b "(begin $defcurves (kbu-satsvis-curves $opacity \"*.[jJ][pP][gG]\"))" -b '(gimp-quit 0)'

;;; where 0<opacity<100, and you've read a gimp curve file into
;;; $defcurves with e.g.

;; $ defcurves=$(< ~/.gimp-2.8/curves/KodakPortra awk  '
;;     BEGIN{
;;         print "(define (my-curves)\n  (quote ("
;;     }
;;     /^[0-9 -]+$/{print "    ("$0")"} # simple curve file format
;;     /^ *\(points [0-9 .-]+\) *$/ {   # GIMP curve settings format
;;         printf "    ("
;;         for(i=3;i<=NF;i++) {
;;             sub(/\)/,"",$i)
;;             if($i ~ /^-/) printf "" # "-1 "
;;             else printf "%d ", $i*255
;;         }
;;         print ")"
;;     }
;;     END{print ")))"}')

;;; This will make "$defcurves" contain something like:
;; (define (my-curves)
;;   '((0 0 128 118 221 215  -1  -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 255 255)
;;     (0 0  41  28 183 209  -1  -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 255 255)
;;     (0 0  25  21  95 102 181 208 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 255 255)
;;     (0 0  25  21 122 153 165 206 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 255 255)
;;     (0 0 -1   -1  -1  -1  -1  -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 255 255))
;;   )

(define (kbu-apply-curves drawable curves)
  (map (lambda (channel)
	 (gimp-curves-spline drawable
			     channel
			     (length (nth channel curves))
			     (list->vector (nth channel curves))))
       (if (= 0 (car (gimp-drawable-has-alpha drawable)))
	   (list HISTOGRAM-VALUE HISTOGRAM-RED HISTOGRAM-GREEN HISTOGRAM-BLUE)
	   (list HISTOGRAM-VALUE HISTOGRAM-RED HISTOGRAM-GREEN HISTOGRAM-BLUE HISTOGRAM-ALPHA))))

(define (kbu-find-eqv elt list)
  (if (pair? list)
      (if (eqv? elt (car list))
	  0
	  (let ((ret (kbu-find-eqv elt (cdr list))))
	    (if (number? ret) (+ 1 ret) '())))))

(define (kbu-basename filename)
  (let* ((slash-pos (kbu-find-eqv #\/ (reverse (string->list filename))))
	 (last-slash
	  (if (number? slash-pos)
	      (- (string-length filename) slash-pos)
	      0)))
    (substring filename last-slash (string-length filename))))

(define (kbu-curve-an-image opacity-curves image filename)
  (let* ((drawable (car (gimp-image-get-active-layer image)))
         ;; viscopy is not used in the image, only as a template when
         ;; creating the curve layers, since we don't want the second
         ;; curve to be based on what's visible after applying the
         ;; first
         (viscopy (car (gimp-layer-new-from-visible image image "copy of visible"))))

    ;; TODO: this should only happen if not xcf, no?
    ;; (gimp-item-set-name drawable (kbu-basename filename))

    (map (lambda (na-op-cu)
           (let ((layer (car (gimp-layer-copy viscopy FALSE)))
                 (name     (car na-op-cu))
                 (opacity (cadr na-op-cu))
                 (curves (caddr na-op-cu)))
             (gimp-item-set-name layer name)
             (gimp-image-insert-layer image layer 0 -1)
             (gimp-layer-set-opacity layer opacity)
             (kbu-apply-curves layer curves)))
         opacity-curves)))

(define (kbu-save-export image filename)
  (let ((drawable (car (gimp-image-get-active-layer image)))
        (xcfname (string-append (kbu-basename filename) ".curved.xcf"))
        (jpgname (string-append (kbu-basename filename) ".curved.xcf.jpg")))
    (gimp-message (string-append "Lagrar som " xcfname " ..."))
    (gimp-xcf-save RUN-NONINTERACTIVE
                   image
                   drawable
                   xcfname
                   xcfname)
    (gimp-image-flatten image)
    (set! drawable (car (gimp-image-get-active-layer image)))
    (gimp-message (string-append "Lagrar som " jpgname " ..."))
    (file-jpeg-save RUN-NONINTERACTIVE
                    image
                    drawable
                    jpgname
                    jpgname
                    1		; kvalitet
                    0		; utjamning
                    1		; optimaliser
                    0		; progressiv
                    "Created with GIMP by ~T~"
                    3		; subsmp, 3 is best quality (?)
                    1		; force baseline
                    0		; restart markers
                    0		; dct slow
                    )))

(define (kbu-satsvis-curves opacity-curves globs)
  "globs is a list of file-globs, e.g. '(\"*.jpg\" \"*.[xX][cC][fF]\"),
opacity-curves is a list of lists of layer-name, opacity-values and curve specs,
e.g. '((\"velvia\" 40 (…)) (\"portra\" 60 (…))) where the … is as described in the top
of this file."
  (let* ((filelist (apply append (map (lambda (glob)
                                        (cadr (file-glob glob 1)))
                                      globs))))
    (map (lambda (filename)
           (gimp-message (string-append "Innbilete: " filename))
           (let ((image (car (gimp-file-load RUN-NONINTERACTIVE
                                             filename filename))))
             (kbu-curve-an-image opacity-curves image filename)
             (kbu-save-export image filename)
             (gimp-image-delete image)))
         filelist))
  (gimp-message "Ferdig med alle bileta!"))


(define (kbu-layer-cover-image1 image drawable)
  ;; no undo group or display flush
  (let* ((width (car (gimp-image-width image)))
         (height (car (gimp-image-height image))))
    (gimp-layer-scale
     drawable
     width
     height
     1))
  (gimp-layer-set-offsets drawable
			  0
			  0))
(define (kbu-layer-load-add-cover image filename mode-symbol opacity)
  (gimp-message (string-append "Prøver å leggja til " filename
			       " med modus " (symbol->string mode-symbol)
			       " og dekkevne " (number->string opacity)))
  (let* ((newlayer (car (gimp-file-load-layer RUN-NONINTERACTIVE image filename))))
    (gimp-image-insert-layer image newlayer 0 -1)
    (kbu-layer-cover-image1 image newlayer)
    (gimp-layer-set-mode newlayer (eval mode-symbol))
    (gimp-layer-set-opacity newlayer opacity)))

(define (kbu-satsvis-textures-curves textures opacity-curves globs)
  "globs is a list of file-globs, e.g. '(\"*.jpg\" \"*.[xX][cC][fF]\"),

opacity-curves is a list of lists of layer-name, opacity-values and curve specs,
e.g. '((\"velvia\" 40 (…)) (\"portra\" 60 (…))) where the … is as described in the top
of this file.

textures er ei liste der kvart element er ei liste
med (filnamn modus-symbol dekkevne), modus må vera sitert
sidan me skriv det ut."
  (let* ((filelist (apply append (map (lambda (glob)
                                        (cadr (file-glob glob 1)))
                                      globs))))
    (map (lambda (filename)
           (gimp-message (string-append "Innbilete: " filename))
           (let ((image (car (gimp-file-load RUN-NONINTERACTIVE
                                             filename filename))))

             (kbu-curve-an-image opacity-curves image filename)

	     (map (lambda (l)
		    (kbu-layer-load-add-cover image (car l) (cadr l) (caddr l)))
		  textures)
	     (gimp-message "Alle lag er lagt til!")

             (kbu-save-export image filename)
             (gimp-image-delete image)))
         filelist))
  (gimp-message "Ferdig med alle bileta!"))
