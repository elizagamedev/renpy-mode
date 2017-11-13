;;; renpy-mode.el -- Ren'Py script support for Emacs

;; Copyright (C) 2017 Eliza Velasquez

;; Author: Eliza Velasquez <elizagamedev@gmail.com>
;; Created: Nov 2017
;; Version: 0.1.0
;; Keywords: languages

;;; Commentary:

;; An Emacs major mode derived from python-mode for use in editing Ren'Py script
;; files. This script provides syntax highlighting, indentation rules, Imenu
;; support for various definitions, and an interface for running the project
;; with Ren'Py.

(require 'python)
(require 'imenu)

;;; Code:

;;; Font Lock

(defvar renpy-keywords
  '("add"
    "animation"
    "at"
    "bar"
    "behind"
    "block"
    "button"
    "call"
    "choice"
    "circles"
    "clockwise"
    "contains"
    "counterclockwise"
    "default"
    "define"
    "event"
    "expression"
    "fixed"
    "frame"
    "from"
    "function"
    "grid"
    "has"
    "hbox"
    "hide"
    "hotbar"
    "hotspot"
    "image"
    "imagebutton"
    "imagemap"
    "init"
    "input"
    "jump"
    "key"
    "knot"
    "label"
    "menu"
    "null"
    "nvl"
    "on"
    "onlayer"
    "parallel"
    "pause"
    "play"
    "python"
    "queue"
    "repeat"
    "scene"
    "screen"
    "set"
    "show"
    "side"
    "stop"
    "style"
    "text"
    "textbutton"
    "time"
    "timer"
    "transform"
    "translate"
    "use"
    "vbar"
    "vbox"
    "viewport"
    "voice"
    "window"
    "zorder"))

(defvar renpy-font-lock-keywords
  `(("\\$" 0 font-lock-keyword-face)
    ("\\_<\\(default\\|define\\)\\s-+\\(\\(?:\\sw\\|\\s_\\|\\.\\)+\\)\\s-*=" (1 font-lock-keyword-face) (2 font-lock-variable-name-face))
    ("\\_<\\(image\\)\\(\\(?:\\sw\\|\\s_\\|\\s-\\)+\\)\\(?::\\|=\\)" (1 font-lock-keyword-face) (2 font-lock-variable-name-face))
    ("\\_<\\(transform\\)\\s-+\\(\\(?:\\sw\\|\\s_\\)+\\)\\s-*:" (1 font-lock-keyword-face) (2 font-lock-variable-name-face))
    ("\\_<\\(label\\|menu\\)\\s-+\\(\\.?\\(?:\\sw\\|\\s_\\)+\\)\\s-*:" (1 font-lock-keyword-face) (2 font-lock-function-name-face))
    ("\\_<\\(menu\\)\\s-*:" (1 font-lock-keyword-face))
    ("\\_<\\(from\\)\\s-+\\(\\(?:\\sw\\|\\s_\\)+\\)" (1 font-lock-keyword-face) (2 font-lock-function-name-face))
    ("\\_<\\(screen\\)\\s-+\\(\\(?:\\sw\\|\\s_\\)+\\)\\s-*(.*?)\\s-*:" (1 font-lock-keyword-face) (2 font-lock-function-name-face))
    ("\\_<\\(style\\)\\s-+\\(\\(?:\\sw\\|\\s_\\)+\\)\\s-*.*:?" (1 font-lock-keyword-face) (2 font-lock-type-face))
    (,(regexp-opt renpy-keywords 'symbols) 0 font-lock-keyword-face)))

;;; Indent/Newline

(defconst renpy-no-indent-regexp
  (mapconcat 'identity
   '("\\s-*\\(?:default\\|define\\)\\s-+\\(?:\\sw\\|\\s_\\|\\.\\)+\\s-*="
     "\\s-*label\\s-+\\.?\\(?:\\sw\\|\\s_\\)+\\s-*:"
     "\\s-*screen\\s-+\\(?:\\sw\\|\\s_\\)+\\s-*(.*?)\\s-*:"
     "\\s-*style\\s-+\\(?:\\sw\\|\\s_\\)+\\(?:\\s-*:\\|\\s-+is\\s-+\\(?:\\sw\\|\\s_\\)+\\)")
   "\\|")
  "A regexp which matches lines which should start at column 0.")

(defun renpy-no-indent-line-p ()
  "Return non-nil if the current line should not indent."
  (save-excursion
    (beginning-of-line)
    (looking-at-p renpy-no-indent-regexp)))

(defun renpy-indent-line (&optional previous)
  "Internal implementation of `renpy-indent-line-function'.
Use the PREVIOUS level when argument is non-nil, otherwise indent
to the maximum available level.  When indentation is the minimum
possible and PREVIOUS is non-nil, cycle back to the maximum
level."
  (interactive)
  (if previous
      (if (eq (current-indentation) 0)
          (renpy-indent-line)
        (indent-line-to (- (current-indentation) python-indent-offset)))
    (if (renpy-no-indent-line-p)
        (indent-line-to 0)
      (progn
        (python-indent-line-function)
        ;; Indent after Ren'Py blocks
        (let ((indent-col (current-indentation))
              (abort nil))
          (save-excursion
            (beginning-of-line)
            (while (not abort)
              (forward-line -1)
              (cond ((looking-at-p "^\\s-*?\\(\\s<.*?\\s>\\)?\\s-*?$"))
                    ((looking-at-p "^\\s-*?.*?:\\s-*?\\(\\s<.*?\\s>\\)?\\s-*?$")
                     (progn
                       (setq indent-col (+ (current-indentation) python-indent-offset))
                       (setq abort t)))
                    (t (setq abort t)))
              (when (equal (point-min) (point))
                (setq abort t))))
          (indent-line-to indent-col))))))

(defun renpy-newline ()
  "Insert a new line.
Ensure proper indentation of Ren'Py constructs without affecting
Python code."
  (interactive)
  (if (bound-and-true-p electric-indent-mode)
      (if (renpy-no-indent-line-p)
          (reindent-then-newline-and-indent)
        (newline-and-indent))
    (newline t)))

(defun renpy-indent-line-function ()
  "`indent-line-function' for Ren'Py mode.
When the variable `last-command' is equal to one of the symbols
inside `renpy-indent-trigger-commands' it cycles possible
indentation levels from right to left."
  (renpy-indent-line
   (and (memq this-command python-indent-trigger-commands)
        (eq last-command this-command))))


;;; Imenu

(defvar renpy-generic-imenu
  '(("label"  "\\_<\\(?:label\\|menu\\)\\s-+\\(\\(?:\\sw\\|\\s_\\)+\\)\\s-*:" 1)
    ("label"  "\\_<call\\s-+\\s_+\\s-+from\\s-+\\(\\(?:\\sw\\|\\s_\\)+\\)" 1)
    ("screen" "\\_<screen\\s-+\\(\\(?:\\sw\\|\\s_\\)+\\)\\s-*(.*?)\\s-*:" 1)
    ("style"  "\\_<style\\s-+\\(\\(?:\\sw\\|\\s_\\)+\\)\\s-*.*:?" 1)
    ("class"  "\\_<class\\s-+\\(\\(?:\\sw\\|\\s_\\)+\\)\\s-*(.*?)\\s-*:" 1)
    ("def"    "\\_<def\\s-+\\(\\(?:\\sw\\|\\s_\\)+\\)\\s-*(.*?)\\s-*:" 1)))


;;; Running Ren'Py processes

(defvar renpy-default-game-directory nil
  "The directory of a Ren'Py project used by default.")

(defvar renpy-command "renpy"
  "The command used to run Ren'Py.")

(defconst renpy-edit-py-file-name
  (concat (file-name-directory (or load-file-name (buffer-file-name))) "emacs.edit.py"))

(defun renpy-game-directory ()
  "Find the root Ren'Py project directory.
The path is relative to the current buffer's file path."
  (expand-file-name (or (locate-dominating-file (buffer-file-name)
                                                "game")
                        (locate-dominating-file default-directory
                                                "game")
                        renpy-default-game-directory)))

(defun renpy-relative-file-name ()
  "Return the path of this file relative to the game directory."
  (file-relative-name (buffer-file-name) (concat (renpy-game-directory) "game/")))

(defun renpy-command (buffer &rest args)
  "Run a Ren'Py command.
Output will be sent to a `special-mode' buffer called BUFFER and
called with the arguments supplied in ARGS."
  (when (and buffer (get-buffer buffer))
    (kill-buffer buffer))
  (let ((default-directory (renpy-game-directory))
	(process-environment process-environment))
    (setenv "RENPY_EDIT_PY" renpy-edit-py-file-name)
    (apply 'start-process
           (append `("renpy"
                     ,buffer
                     ,renpy-command
                     ".")
                   args)))
  (when buffer
    (switch-to-buffer-other-window buffer)
    (special-mode)))

(defun renpy-lint ()
  "Run the Ren'Py linter."
  (interactive)
    (renpy-command "*renpy lint*" "lint"))

(defun renpy-run ()
  "Run the Ren'Py game."
  (interactive)
  (renpy-command nil "run"))

(defun renpy-warp ()
  "Run the game, warping to the current line."
  (interactive)
  (renpy-command nil "run" "--warp"
                 (concat (renpy-relative-file-name)
                         ":"
                         (number-to-string (line-number-at-pos)))))


;;; Keymap

(defvar renpy-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "RET") 'renpy-newline)
    (define-key map (kbd "C-c C-l") 'renpy-lint)
    (define-key map (kbd "C-c C-c") 'renpy-run)
    (define-key map (kbd "C-c C-w") 'renpy-warp)
    map))


;;; Mode definition

(define-derived-mode renpy-mode python-mode "Ren'Py"
  "Major mode for Ren'Py scripts"

  (font-lock-add-keywords nil renpy-font-lock-keywords)
  (setq indent-line-function 'renpy-indent-line-function)

  (setq imenu-create-index-function 'imenu-default-create-index-function)
  (setq imenu-generic-expression renpy-generic-imenu))

(add-to-list 'auto-mode-alist '("\\.rpym?\\'" . renpy-mode))

(provide 'renpy-mode)
;;; renpy-mode.el ends here
