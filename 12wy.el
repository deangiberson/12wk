;;; 12wy.el --- 12-Week Year tracking for Emacs -*- lexical-binding: t; -*-

;; Author: User
;; Version: 0.1.0
;; Package-Requires: ((emacs "27.1"))
;; Keywords: calendar, org
;; URL: https://github.com/user/12wy.el

;;; Commentary:
;; Track goals using the 12-Week Year methodology.
;; Point at an org file, get views and tracking.

;;; Code:

(require 'org)
(require 'cl-lib)

;;; Customization

(defgroup 12wy nil
  "12-Week Year tracking."
  :group 'org
  :prefix "12wy-")

(defcustom 12wy-file nil
  "Path to current 12-week year org file."
  :type '(choice (const nil) file)
  :group '12wy)

(defcustom 12wy-target-score 85
  "Target execution percentage."
  :type 'integer
  :group '12wy)

;;; Parsing

(defun 12wy--parse-file ()
  "Parse the 12wy org file. Return plist with :start :goals :weeks."
  (unless 12wy-file (user-error "No 12wy file set. Use M-x 12wy-set-file"))
  (with-temp-buffer
    (insert-file-contents 12wy-file)
    (org-mode)
    (let ((start (12wy--parse-start))
          (goals (12wy--parse-goals))
          (weeks (12wy--parse-weeks)))
      (list :start start :goals goals :weeks weeks))))

(defun 12wy--parse-start ()
  "Parse #+12WY_START date."
  (goto-char (point-min))
  (when (re-search-forward "^#\\+12WY_START:[ \t]*\\([0-9-]+\\)" nil t)
    (match-string 1)))

(defun 12wy--parse-goals ()
  "Parse Goals section. Return list of (goal-name . (tactic ...))."
  (goto-char (point-min))
  (let (goals)
    (when (re-search-forward "^\\* Goals$" nil t)
      (let ((end (save-excursion (or (re-search-forward "^\\* " nil t) (point-max)))))
        (while (re-search-forward "^\\*\\* \\(Goal [0-9]+: .+\\)$" end t)
          (let ((goal-name (match-string 1))
                (goal-end (save-excursion (or (re-search-forward "^\\*\\* " end t) end)))
                tactics)
            (while (re-search-forward "^\\*\\*\\* \\(?:TODO \\|DONE \\)?Tactic: \\(.+\\)$" goal-end t)
              (push (match-string 1) tactics))
            (push (cons goal-name (nreverse tactics)) goals)))))
    (nreverse goals)))

(defun 12wy--parse-weeks ()
  "Parse Weekly Log. Return list of (week-num date . ((tactic . done-p) ...))."
  (goto-char (point-min))
  (let (weeks)
    (when (re-search-forward "^\\* Weekly Log$" nil t)
      (let ((end (save-excursion (or (re-search-forward "^\\* " nil t) (point-max)))))
        (while (re-search-forward "^\\*\\* Week \\([0-9]+\\) <\\([0-9-]+\\)>" end t)
          (let ((week-num (string-to-number (match-string 1)))
                (date (match-string 2))
                (week-end (save-excursion (or (re-search-forward "^\\*\\* " end t) end)))
                tactics)
            (while (re-search-forward "^- \\[\\([X ]\\)\\] \\(.+\\)$" week-end t)
              (push (cons (match-string 2) (string= (match-string 1) "X")) tactics))
            (push (cons week-num (cons date (nreverse tactics))) weeks)))))
    (nreverse weeks)))

(defun 12wy--all-tactics (goals)
  "Get flat list of all tactics from GOALS."
  (cl-loop for (goal . tactics) in goals append tactics))

(defun 12wy--current-week (start-date)
  "Calculate current week number from START-DATE."
  (let* ((start (date-to-day (parse-time-string start-date)))
         (today (date-to-day (decode-time)))
         (days (- today start)))
    (1+ (/ days 7))))

(defun 12wy--week-score (week-data)
  "Calculate score for WEEK-DATA as percentage."
  (let* ((tactics (cddr week-data))
         (total (length tactics))
         (done (cl-count-if #'cdr tactics)))
    (if (zerop total) 0 (round (* 100.0 (/ (float done) total))))))

;;; Commands

;;;###autoload
(defun 12wy-set-file (file)
  "Set FILE as the 12-week year org file."
  (interactive "fSelect 12-week year org file: ")
  (setq 12wy-file file)
  (message "12wy file set to %s" file))

;;;###autoload
(defun 12wy-weekly-view ()
  "Show current week's tactics and score."
  (interactive)
  (let* ((data (12wy--parse-file))
         (start (plist-get data :start))
         (weeks (plist-get data :weeks))
         (week-num (12wy--current-week start))
         (week (cl-find week-num weeks :key #'car))
         (buf (get-buffer-create "*12wy Weekly*")))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (format "Week %d" week-num))
        (when week (insert (format " <%s>" (cadr week))))
        (insert "\n\n")
        (if (not week)
            (insert "No data for this week yet.\n")
          (dolist (tactic (cddr week))
            (insert (format "[%s] %s\n" (if (cdr tactic) "X" " ") (car tactic))))
          (insert (format "\nScore: %d%%" (12wy--week-score week)))
          (when (>= (12wy--week-score week) 12wy-target-score)
            (insert " ✓")))
        (insert "\n\n")
        (insert-text-button "Open org file"
                            'action (lambda (_) (find-file 12wy-file)))
        (goto-char (point-min))
        (special-mode)))
    (pop-to-buffer buf)))

;;;###autoload
(defun 12wy-dashboard ()
  "Show dashboard with goals×weeks table."
  (interactive)
  (let* ((data (12wy--parse-file))
         (goals (plist-get data :goals))
         (weeks (plist-get data :weeks))
         (tactics (12wy--all-tactics goals))
         (buf (get-buffer-create "*12wy Dashboard*")))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (let* ((max-tactic-len (apply #'max 20 (mapcar #'length tactics)))
               (col-width 4))
          ;; Header
          (insert (format "%-*s" max-tactic-len "Tactic"))
          (dotimes (w 12)
            (insert (format " W%-2d" (1+ w))))
          (insert "   %\n")
          (insert (make-string (+ max-tactic-len (* 12 col-width) 5) ?─) "\n")
          ;; Rows
          (dolist (tactic tactics)
            (insert (format "%-*s" max-tactic-len (truncate-string-to-width tactic max-tactic-len)))
            (let ((done-count 0) (total-count 0))
              (dotimes (w 12)
                (let* ((week (cl-find (1+ w) weeks :key #'car))
                       (entry (and week (assoc tactic (cddr week)))))
                  (cond
                   ((not week) (insert "    "))
                   ((not entry) (insert "  - "))
                   ((cdr entry) (insert "  ✓ ") (cl-incf done-count) (cl-incf total-count))
                   (t (insert "  ✗ ") (cl-incf total-count)))))
              (insert (format " %3d%%" (if (zerop total-count) 0 (round (* 100.0 (/ (float done-count) total-count))))))))
          (insert "\n" (make-string (+ max-tactic-len (* 12 col-width) 5) ?─) "\n")
          ;; Weekly scores
          (insert (format "%-*s" max-tactic-len "Weekly Score"))
          (let ((total-score 0) (week-count 0))
            (dotimes (w 12)
              (let ((week (cl-find (1+ w) weeks :key #'car)))
                (if (not week)
                    (insert "    ")
                  (let ((score (12wy--week-score week)))
                    (insert (format "%3d%%" score))
                    (cl-incf total-score score)
                    (cl-incf week-count)))))
            (insert (format " %3d%%" (if (zerop week-count) 0 (round (/ (float total-score) week-count))))))
          (insert "\n"))
        (goto-char (point-min))
        (special-mode)))
    (pop-to-buffer buf)))

;;;###autoload
(defun 12wy-new-week ()
  "Insert new week entry with tactics from Goals."
  (interactive)
  (let* ((data (12wy--parse-file))
         (goals (plist-get data :goals))
         (weeks (plist-get data :weeks))
         (next-week (1+ (if weeks (apply #'max (mapcar #'car weeks)) 0)))
         (tactics (12wy--all-tactics goals))
         (date (format-time-string "%Y-%m-%d")))
    (find-file 12wy-file)
    (goto-char (point-min))
    (if (re-search-forward "^\\* Weekly Log$" nil t)
        (progn
          (org-end-of-subtree)
          (insert "\n"))
      (goto-char (point-max))
      (insert "\n* Weekly Log\n"))
    (insert (format "** Week %d <%s>\n" next-week date))
    (dolist (tactic tactics)
      (insert (format "- [ ] %s\n" tactic)))))

;;;###autoload
(defun 12wy-insert-review ()
  "Insert end-of-period review template."
  (interactive)
  (find-file 12wy-file)
  (goto-char (point-min))
  (if (re-search-forward "^\\* Review$" nil t)
      (org-end-of-subtree)
    (goto-char (point-max))
    (insert "\n* Review"))
  (insert "\n** What went well?\n\n** What didn't go well?\n\n** What will I do differently?\n\n** Goal outcomes\n| Goal | Target | Actual | Notes |\n|------+--------+--------+-------|\n|      |        |        |       |\n"))

;;;###autoload
(defun 12wy-insert-prep ()
  "Insert next period prep template."
  (interactive)
  (find-file 12wy-file)
  (goto-char (point-min))
  (if (re-search-forward "^\\* Next Period Prep$" nil t)
      (org-end-of-subtree)
    (goto-char (point-max))
    (insert "\n* Next Period Prep"))
  (insert "\n** Vision (what does success look like?)\n\n** Goals for next 12 weeks\n*** Goal 1:\n**** Tactic:\n**** Tactic:\n\n** Potential obstacles\n\n** Commitments\n"))

(provide '12wy)
;;; 12wy.el ends here
