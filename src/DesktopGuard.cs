using System;
using System.Runtime.InteropServices;
using System.Text;
using System.Collections.Generic;

namespace DesktopGuard {
    [ComImport]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    [Guid("a5cd92ff-29be-454c-8d04-d82879fb3f1b")]
    public interface IVirtualDesktopManager {
        int IsWindowOnCurrentVirtualDesktop(IntPtr topLevelWindow, out bool onCurrentDesktop);
        int GetWindowDesktopId(IntPtr topLevelWindow, out Guid desktopId);
        int MoveWindowToDesktop(IntPtr topLevelWindow, ref Guid desktopId);
    }

    public class WindowInfo {
        public long Hwnd { get; set; }
        public uint Pid { get; set; }
        public string ClassName { get; set; }
        public string Title { get; set; }
        public Guid DesktopId { get; set; }
        public bool OnCurrentDesktop { get; set; }
        public int Left { get; set; }
        public int Top { get; set; }
        public int Width { get; set; }
        public int Height { get; set; }
        public int ShowCmd { get; set; }
    }

    public static class Win32Helper {
        public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

        [DllImport("user32.dll")]
        public static extern bool EnumWindows(EnumWindowsProc enumProc, IntPtr lParam);

        [DllImport("user32.dll")]
        public static extern bool IsWindowVisible(IntPtr hWnd);

        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        public static extern int GetWindowText(IntPtr hWnd, StringBuilder strText, int maxCount);

        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        public static extern int GetWindowTextLength(IntPtr hWnd);

        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        public static extern int GetClassName(IntPtr hWnd, StringBuilder lpClassName, int nMaxCount);

        [DllImport("user32.dll")]
        public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

        [DllImport("user32.dll")]
        public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

        [DllImport("user32.dll")]
        public static extern bool GetWindowPlacement(IntPtr hWnd, ref WINDOWPLACEMENT lpwndpl);

        [DllImport("user32.dll")]
        public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);

        [DllImport("user32.dll")]
        public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

        [DllImport("user32.dll", CharSet = CharSet.Auto)]
        public static extern bool SystemParametersInfo(uint uiAction, uint uiParam, string pvParam, uint fWinIni);

        [StructLayout(LayoutKind.Sequential)]
        public struct RECT {
            public int Left;
            public int Top;
            public int Right;
            public int Bottom;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct POINT {
            public int X;
            public int Y;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct WINDOWPLACEMENT {
            public int length;
            public int flags;
            public int showCmd;
            public POINT ptMinPosition;
            public POINT ptMaxPosition;
            public RECT rcNormalPosition;
        }

        public static List<WindowInfo> GetTopLevelWindows() {
            var list = new List<WindowInfo>();
            IVirtualDesktopManager vdm = null;
            try {
                var vdmType = Type.GetTypeFromCLSID(new Guid("aa509086-5ca9-4c25-8f95-589d3c07b48a"));
                if (vdmType != null) {
                    vdm = (IVirtualDesktopManager)Activator.CreateInstance(vdmType);
                }
            } catch {}

            EnumWindows((hWnd, lParam) => {
                if (IsWindowVisible(hWnd)) {
                    int len = GetWindowTextLength(hWnd);
                    if (len > 0) {
                        uint pid = 0;
                        GetWindowThreadProcessId(hWnd, out pid);
                        var sbClass = new StringBuilder(256);
                        GetClassName(hWnd, sbClass, 256);
                        string cls = sbClass.ToString();
                        if (cls != "Progman" && cls != "WorkerW" && cls != "Shell_TrayWnd" && cls != "Shell_SecondaryTrayWnd") {
                            var sbTitle = new StringBuilder(len + 1);
                            GetWindowText(hWnd, sbTitle, len + 1);
                            RECT r;
                            GetWindowRect(hWnd, out r);
                            WINDOWPLACEMENT wp = new WINDOWPLACEMENT();
                            wp.length = Marshal.SizeOf(wp);
                            GetWindowPlacement(hWnd, ref wp);

                            Guid deskId = Guid.Empty;
                            bool onCurrent = false;
                            if (vdm != null) {
                                try {
                                    vdm.GetWindowDesktopId(hWnd, out deskId);
                                    vdm.IsWindowOnCurrentVirtualDesktop(hWnd, out onCurrent);
                                } catch {}
                            }

                            if (deskId != Guid.Empty && (r.Right - r.Left) > 50 && (r.Bottom - r.Top) > 50) {
                                list.Add(new WindowInfo {
                                    Hwnd = hWnd.ToInt64(),
                                    Pid = pid,
                                    ClassName = cls,
                                    Title = sbTitle.ToString(),
                                    DesktopId = deskId,
                                    OnCurrentDesktop = onCurrent,
                                    Left = r.Left,
                                    Top = r.Top,
                                    Width = r.Right - r.Left,
                                    Height = r.Bottom - r.Top,
                                    ShowCmd = wp.showCmd
                                });
                            }
                        }
                    }
                }
                return true;
            }, IntPtr.Zero);

            return list;
        }
    }
}
