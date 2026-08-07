;;; setup_reports.scm
;;; 为每个监测点、每个变量创建 Report Definition，并统一写入一个 Report File
;;;
;;; 使用方法：
;;;   (load "temp/params.scm")   ; 必须先加载参数文件
;;;   (load "setup_reports.scm")
;;;   (setup-reports)
;;;
;;; 依赖变量：
;;;   probe-list      : 监测点列表
;;;   var-list        : 变量列表，形如 (("P" . "pressure") ("Ux" . "x-velocity") ...)
;;;   report-file-object-name : Report File 对象名，例如 "pressure_signal_record"
;;;   report-file-output-name : Report File 输出文件名，例如 "Results/Case001/Case001.out"

(define (make-report-name probe-name var)
  (format #f "~a_~a" probe-name var))

(define (create-report-definition report-name surface-name field)
  ;; 创建 surface-vertexmax 类型的 report definition
  ;; 单点情况下，vertexmax / vertexavg / vertexmin 结果几乎一致
  ;; 这里沿用你原 journal 中的 Vertex Maximum 设置
  (let ((cmd (format #f "/solve/report-definitions/add ~a surface-vertexmax surface-names ~a , field ~a q"
                     report-name surface-name field)))
    (ti-menu-load-string cmd)))

(define (string-join sep lst)
  ;; 自定义字符串连接函数，Scheme 标准不一定提供 string-join
  (if (null? lst)
      ""
      (let loop ((result (car lst)) (rest (cdr lst)))
        (if (null? rest)
            result
            (loop (string-append result sep (car rest)) (cdr rest))))))

(define (chunk-list lst size)
  ;; 将列表按 size 大小分块
  (if (null? lst)
      '()
      (let ((head (list-head lst size)))
        (cons head (chunk-list (list-tail lst size) size)))))

(define (list-head lst n)
  (if (or (= n 0) (null? lst))
      '()
      (cons (car lst) (list-head (cdr lst) (- n 1)))))

(define (list-tail lst n)
  (if (or (= n 0) (null? lst))
      lst
      (list-tail (cdr lst) (- n 1))))

(define (setup-reports)
  (newline)
  (display "==> Creating report definitions...") (newline)
  (let ((total-defs 0))
    (for-each
      (lambda (var-pair)
        (let ((var (car var-pair))
              (field (cdr var-pair)))
          (for-each
            (lambda (probe)
              (let* ((probe-name (car probe))
                     (report-name (make-report-name probe-name var)))
                (create-report-definition report-name probe-name field)
                (set! total-defs (+ total-defs 1))
                (if (= (modulo total-defs 100) 0)
                    (display (format #f "    ~a definitions created...~%" total-defs)))))
            probe-list)))
      var-list)
    (display (format #f "==> Done. ~a report definitions created.~%" total-defs)))

  (newline)
  (display "==> Creating report file and attaching definitions...") (newline)
  ;; 收集所有 report definition 名称
  (let* ((all-report-names
           (apply append
             (map (lambda (var-pair)
                    (let ((var (car var-pair)))
                      (map (lambda (probe)
                             (make-report-name (car probe) var))
                           probe-list)))
                  var-list)))
         (chunks (chunk-list all-report-names 50)))
    ;; 先创建 report file，并加入第一批 definition
    (let ((first-chunk (car chunks)))
      (ti-menu-load-string
        (format #f "/solve/report-files/add ~a report-defs ~a , q"
                report-file-object-name
                (string-join " " first-chunk))))
    ;; 剩余 definition 分批加入
    (let loop ((rest (cdr chunks)) (batch 2))
      (if (not (null? rest))
          (begin
            (ti-menu-load-string
              (format #f "/solve/report-files/edit ~a add-report-defs ~a"
                      report-file-object-name
                      (string-join " " (car rest))))
            (display (format #f "    Batch ~a / ~a attached...~%" batch (length chunks)))
            (loop (cdr rest) (+ batch 1)))))
    ;; 设置输出文件名（可选；Fluent 某些版本下该 TUI 行为不一致，
    ;; 因此默认让 Fluent 输出到工作目录的 pressure_signal_record.out，
    ;; 再由 Python 移动到 Results 目录。）
    ;; (ti-menu-load-string
    ;;   (format #f "/solve/report-files/edit ~a file-name \"~a\""
    ;;           report-file-object-name report-file-output-name))
    (display (format #f "==> Done. Report file object: ~a~%" report-file-object-name))
    (newline)))
