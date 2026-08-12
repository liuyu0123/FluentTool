;;; create_points.scm
;;; 自动创建监测点 Point Surface
;;;
;;; 使用方法：
;;;   (load "temp/params.scm")   ; 必须先加载参数文件
;;;   (load "create_points.scm")
;;;   (create-all-probes)
;;;
;;; 依赖变量（由 Python 生成到 temp/params.scm）：
;;;   probe-list : 形如 (("P_x00_y-05_z00" 0.0 -0.05 0.0) ...)

(define (create-probe name x y z)
  ;; 使用 Fluent TUI 创建 point-surface
  ;; 名称和坐标均以字符串形式从 params.scm 传入，避免 Scheme 浮点格式兼容问题
  (let ((cmd (format #f "/surface/point-surface \"~a\" ~a ~a ~a" name x y z)))
    (ti-menu-load-string cmd)))

(define (create-all-probes)
  (newline)
  (display (format #f "==> Creating ~a probe points...~%" (length probe-list)))
  (let loop ((lst probe-list) (n 1))
    (if (not (null? lst))
        (let* ((p (car lst))
               (name (car p))
               (x (cadr p))
               (y (caddr p))
               (z (cadddr p)))
          (if (= (modulo n 100) 0)
              (display (format #f "    ~a / ~a points created...~%" n (length probe-list))))
          (create-probe name x y z)
          (loop (cdr lst) (+ n 1)))))
  (display (format #f "==> Done. ~a probe points created.~%" (length probe-list)))
  (newline))
