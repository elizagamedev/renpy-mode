import renpy
import subprocess
import os.path


class Editor(renpy.editor.Editor):

    def begin(self, new_window=False, **kwargs):
        if renpy.windows:
            self.arguments = ["emacsclientw", "-n"]
        else:
            self.arguments = ["emacsclient", "-n"]

    def open(self, filename, line=None, **kwargs):
        # Handle special cases for generated files like lint.txt, errors.txt,
        # and traceback.txt; specifically treat them as read-only special-mode
        # buffers
        basename = os.path.basename(filename)
        filename = renpy.exports.fsencode(filename)
        if basename in {"lint.txt", "errors.txt", "traceback.txt"}:
            # special-mode buffer
            buffer_name = "*renpy {}*".format(os.path.splitext(basename)[0])
            filename = filename.replace(os.sep, '/')
            self.arguments.extend(
                ('-e',
                 '(let ((inhibit-read-only t))' +
                 '(get-buffer-create "{}")'.format(buffer_name) +
                 '(switch-to-buffer-other-window "{}")'.format(buffer_name) +
                 '(insert-file-contents "{}" nil nil nil t)'.format(filename) +
                 '(special-mode))'))
        else:
            # normal file
            if line:
                self.arguments.append("+%d" % line)
            self.arguments.append(filename)

    def end(self, **kwargs):
        subprocess.Popen(self.arguments)
