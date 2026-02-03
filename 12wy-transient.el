;;; 12wy-transient.el --- Transient menu for 12-Week Year -*- lexical-binding: t; -*-

;;; Commentary:
;; Provides a transient menu interface for 12wy commands.

;;; Code:

(require '12wy)
(require 'transient)

;;;###autoload (autoload '12wy "12wy-transient" nil t)
(transient-define-prefix 12wy ()
  "12-Week Year tracking menu."
  ["12-Week Year"
   ("f" "Set file" 12wy-set-file)
   ("w" "Weekly view" 12wy-weekly-view)
   ("d" "Dashboard" 12wy-dashboard)]
  ["Actions"
   ("n" "New week" 12wy-new-week)
   ("r" "End review" 12wy-insert-review)
   ("p" "Prep next" 12wy-insert-prep)])

(provide '12wy-transient)
;;; 12wy-transient.el ends here
