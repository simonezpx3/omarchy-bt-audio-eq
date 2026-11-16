import Quickshell.Io

Process {
  id: proc
  property int maxOutBytes: 131072
  property int maxErrBytes: 8192
  property string outBuf: ""
  property string errBuf: ""
  property bool overflowed: false

  signal finished(string stdoutText, string stderrText, bool wasOverflowed)

  onStarted: {
    outBuf = "";
    errBuf = "";
    overflowed = false;
  }

  stdout: SplitParser {
    splitMarker: ""
    onRead: function(chunk) {
      if (proc.overflowed) return;
      proc.outBuf += chunk;
      if (proc.outBuf.length > proc.maxOutBytes) {
        proc.overflowed = true;
        proc.outBuf = "";
        proc.signal(15);
      }
    }
  }

  stderr: SplitParser {
    splitMarker: ""
    onRead: function(chunk) {
      if (proc.errBuf.length < proc.maxErrBytes) {
        proc.errBuf += chunk.slice(0, proc.maxErrBytes - proc.errBuf.length);
      }
    }
  }

  onExited: function(code, status) {
    const out = proc.outBuf.trim();
    const err = proc.errBuf.trim();
    const ovf = proc.overflowed;
    proc.outBuf = "";
    proc.errBuf = "";
    proc.finished(out, err, ovf);
  }
}
