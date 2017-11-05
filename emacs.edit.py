import renpy
import subprocess


class Editor(renpy.editor.Editor):

    def begin(self, new_window=False, **kwargs):
        self.arguments = ["emacsclient", "-n"]

    def open(self, filename, line=None, **kwargs):
        if line:
            self.arguments.append("+%d" % line)
        filename = renpy.exports.fsencode(filename)
        self.arguments.append(filename)

    def end(self, **kwargs):
        subprocess.Popen(self.arguments)
