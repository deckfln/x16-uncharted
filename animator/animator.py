#!/usr/bin/env python
 
import wx
import wx.lib.scrolledpanel as scrolled
import wx.lib.statbmp
#import wx.lib.inspection

###############################################################################
#
#
class Frame:
    def __init__(self) -> None:
        self.x = 0
        self.y = 0
        self.spriteID = 0
        self.bitmap = None
        self.flipx = False
        self.flipy = False
        self._drag = None
        self._dragX = 0
        self._dragY = 0
        self._deltaX = 0
        self._deltaY = 0

    def draw(self, dc):
        if self.bitmap:
            dc.DrawBitmap(self.bitmap, -8*8 + self.x, self.y, True)

    def dragStart(self, bitmap, point=None):
        if bitmap is not None:
            # drag a new sprite to the Frame
            self._drag = bitmap
            wx.Bitmap.Rescale(self._drag, (256, 256))
            self._deltaX = 0
            self._deltaY = 0
        elif point is not None:
            # drag the existing sprite
            self._deltaX = self.x - int(point.x/8) * 8
            self._deltaY = self.y - int(point.y/8) * 8

    def drag(self, dc, point):
        """
        drag a sprite on the frame
        """
        self._dragX = int(point.x / 8) * 8 + self._deltaX
        self._dragY = int(point.y / 8) * 8 + self._deltaY

        dc.DrawBitmap(self._drag, -8*8 + self._dragX, self._dragY, True)

        dc.SetPen(wx.Pen("black"))
        dc.SetBrush(wx.Brush("blue", wx.TRANSPARENT))
        dc.DrawRectangle(wx.Rect(self._dragX, self._dragY, 128, 256))

    def dragEnd(self): 
        self.bitmap = self._drag
        self.x = self._dragX
        self.y = self._dragY

###############################################################################
#
#
class Cell:
    def __init__(self, x,y, dx, dy) -> None:
        self.rect = wx.Rect(x, y, dx, dy)
        self.tile = None

    def draw(self, dc):
        if self.tile:
            dc.DrawBitmap(self.tile, self.rect.x, self.rect.y, True)
        

###############################################################################
#
#
class EditorPanel(wx.Panel):
    """
    """
    def __init__(self, parent, app):
        super().__init__(parent)

        self._app = app
        self._bitmap = wx.Bitmap(512,512)
        self.sb = wx.lib.statbmp.GenStaticBitmap(self, -1, None, (0, 0), (256, 256))
        self.cells = []
        self.cells.append(Cell(0, 0, 128,128))
        self.cells.append(Cell(128, 0, 128,128))
        self.cells.append(Cell(0, 128, 128,128))
        self.cells.append(Cell(128, 128, 128,128))
        self.currentCell = None
        self.Bind(wx.EVT_PAINT,  self.OnPaint)
        self.frames = [ Frame(), Frame() ]
        self.frame = self.frames[0]
        self._sprite = None
        self._dragTile = None
        self.px = 0
        self.py = 0
        self._drag = False

        self.sb.Bind(wx.EVT_LEFT_DOWN, self.onClick)
        self.sb.Bind(wx.EVT_LEFT_UP, self.onRelease)
        self.sb.Bind(wx.EVT_MOTION, self.onMotion)
        self.sb.Bind(wx.EVT_LEAVE_WINDOW, self.onLeave)

    def onClick(self, event):
        """
        clicking on the editor will move the sprite
        """
        p = wx.Point(event.x, event.y)
        self.frame.dragStart(None, p)
        self._drag = True

    def onMotion(self, event):
        """
        Moving the sprite in the editor
        """
        if self._drag:
            p = wx.Point(event.x, event.y)
            dc = wx.BufferedDC(wx.ClientDC(self.sb))
            dc.Clear()
            self._paintBackground(dc)
            self.frame.drag(dc, p)

    def onLeave(self, event):
        """
        Moving the sprite out of the editor
        """
        if self._drag:
            dc = wx.BufferedDC(wx.ClientDC(self.sb))
            dc.Clear()
            self._paintBackground(dc)
            self.frame.draw(dc)

    def onRelease(self, event):
        """
        Moving the sprite in the editor
        """
        if self._drag:
            self._drag = False
            self.frame.dragEnd()
    
    def beginDragTile(self, bitmap):
        """
        Define the dragged tile
        """
        self._dragTile = bitmap
        wx.Bitmap.Rescale(self._dragTile, (128, 128))

    def moveTile(self, point):
        """
        move a tile to the editor
        """
        dc = wx.BufferedDC(wx.ClientDC(self.sb))
        dc.Clear()
        self._paintBackground(dc)
        for c in self.cells:
            if c.rect.Contains(point):
                self.currentCell = c
                if self._dragTile:
                    dc.DrawBitmap(self._dragTile, c.rect.x, c.rect.y, True)

                dc.SetPen(wx.Pen("black"))
                dc.SetBrush(wx.Brush("blue", wx.TRANSPARENT))
                dc.DrawRectangle(c.rect)

    def endDragTile(self):
        """
        Stop the dragged tile
        """
        self._dragTile = None

    def _paintBackground(self, dc):
        for c in self.cells:
            c.draw(dc)

    def OnPaint(self, event):
        #dc = wx.BufferedPaintDC(self)
        #dc = wx.BufferedDC()
        dc = wx.ClientDC(self.sb)
        dc.Clear()
        self._paintBackground(dc) 
        self.frame.draw(dc)

    def _onLeaveTile(self):
        if self.currentCell:
            self.currentCell = None
            self.Refresh()

    def _onReleaseTile(self):
        self.currentCell.tile = self._dragTile
        self._onLeaveTile()
        self.Refresh()

    def beginDragSprite(self, bitmap):
        """
        Define the current sprite
        """
        self.frame.dragStart(bitmap)

    def moveSprite(self, point):
        """
        move a sprite to the editor
        """
        dc = wx.ClientDC(self.sb)
        dc.Clear()
        self._paintBackground(dc) 
        self.frame.drag(dc, point)

    def _onLeaveSprite(self):
        dc = wx.BufferedDC(wx.ClientDC(self.sb))
        dc.Clear()
        self._paintBackground(dc)

    def _onReleaseSprite(self):
        self._onLeaveSprite()
        self.Refresh()

    def endDragSprite(self):
        """
        Stop the dragged tile
        """
        self.frame.dragEnd()

    def _onLeave(self, type):
        """
        Parent drives a drag&drop, pointer is leaving the editor
        """
        if type == 1:
            self._onLeaveTile()
        elif type == 2:
            self._onLeaveSprite()

    def _onRelease(self, type):
        """
        Parent drives a drag&drop, left mouse was released in the editor
        """
        if type == 1:
            self._onReleaseTile()
        elif type == 2:
            self._onReleaseSprite()

    def setFrame(self, frameID):
        self.frame = self.frames[frameID]
        self.Refresh()

    def addFrame(self):
        self.frames.append(Frame())


###############################################################################
#
#
class PlayerPanel(scrolled.ScrolledPanel):
    """
    """
    def __init__(self, parent, app):
        self._app = app
        scrolled.ScrolledPanel.__init__(self, parent, -1, (0,0), (142,0))

        vbox = wx.BoxSizer(wx.VERTICAL)

        self.tileset = wx.Image("player.png", wx.BITMAP_TYPE_ANY)
        self._png = self.tileset.ConvertToBitmap()
        
        self.sb = wx.StaticBitmap(self, -1, self._png, (0, 0), (self._png.GetWidth(), self._png.GetHeight()))
        vbox.Add(self.sb)

        self.SetSizer(vbox)
        self.SetupScrolling()

        self.sb.Bind(wx.EVT_LEFT_DOWN, self.onClick)

    def onClick(self,event):
        px = int(event.x /326)
        py = int(event.y / 32)
        sprite = self._png.GetSubBitmap(wx.Rect(px * 16, py * 32, 32, 32))
        self._app.msg("sprite", sprite)

###############################################################################
#
#
class TilesPanel(scrolled.ScrolledPanel):
    """
    """
    def __init__(self, guiparent, app):
        self._app = app
        scrolled.ScrolledPanel.__init__(self, guiparent, -1, (0,0), (142,0))

        vbox = wx.BoxSizer(wx.VERTICAL)

        self._tileset = wx.Image("tileset.png", wx.BITMAP_TYPE_ANY)
        self._png = self._tileset.ConvertToBitmap()
        
        sb = wx.StaticBitmap(self, -1, self._png, (0, 0), (self._png.GetWidth(), self._png.GetHeight()))
        vbox.Add(sb)
                
        self.SetSizer(vbox)
        self.SetupScrolling()

        sb.Bind(wx.EVT_LEFT_DOWN, self.onClick)

    def onClick(self,event):
        px = int(event.x / 16)
        py = int(event.y / 16)
        tile = self._png.GetSubBitmap(wx.Rect(px*16, py*16, 16, 16))
        self._app.msg("tile", tile)


###############################################################################
#
#
class Animator(wx.Frame):
    """
    """
    def __init__(self, *args, **kwargs):
        super(Animator, self).__init__(*args, **kwargs)
        self.onEditor = False
        self.InitUI()
        #wx.lib.inspection.InspectionTool().Show()

    def InitUI(self):
        menubar = wx.MenuBar()
        fileMenu = wx.Menu()
        fileItem = fileMenu.Append(wx.ID_EXIT, 'Quit', 'Quit application')
        menubar.Append(fileMenu, '&File')
        self.SetMenuBar(menubar)

        self.Bind(wx.EVT_MENU, self.onQuit, fileItem)
        self.Bind(wx.EVT_MOTION, self.onMotion)
        self.Bind(wx.EVT_LEFT_UP, self.onRelease)

        self.SetSize((800, 512))
        self.SetTitle('Simple menu')
        self.Centre()

        root = wx.Panel(self)

        self.ft = TilesPanel(root, self)
        self.fp = PlayerPanel(root, self)

        self.editor = EditorPanel(root, self)
        self.sld = wx.Slider(root, -1, 0, 0, 1, wx.DefaultPosition, (250, -1), wx.SL_AUTOTICKS | wx.SL_HORIZONTAL | wx.SL_LABELS)
        self.addFrame = wx.Button(root, label="+")

        s = wx.BoxSizer(wx.HORIZONTAL)
        s.Add(self.ft, wx.ALIGN_LEFT, wx.EXPAND)
        s.Add(self.fp, wx.ALIGN_LEFT, wx.EXPAND)

        s1 = wx.BoxSizer(wx.HORIZONTAL)
        s1.Add(self.sld, 1, wx.ALIGN_CENTRE | wx.ALL, 0)
        s1.Add(self.addFrame, wx.ALIGN_LEFT, 0)

        v = wx.BoxSizer(wx.VERTICAL)
        v.Add(self.editor, wx.ALIGN_LEFT, wx.EXPAND | wx.ALL, 0)
        v.Add(s1, wx.ALIGN_LEFT, wx.EXPAND| wx.ALL, 0)

        s.Add(v, wx.ALIGN_LEFT, wx.EXPAND)
        root.SetSizer(s)

        self.Bind(wx.EVT_SLIDER, self.OnSliderScroll)
        self.Bind(wx.EVT_BUTTON, self.onAddFrame)

    def msg(self, message, data):
        match message:
            case 'tile':
                self._drag = 1
                self.drag = wx.DragImage(data)
                self.drag.BeginDrag(wx.Point(0,0), self)
                self.drag.Show()
                self.editor.beginDragTile(data)

            case 'sprite':
                self._bitmap = data
                self._drag = 2
                self.drag = wx.DragImage(data)
                self.drag.BeginDrag(wx.Point(0,0), self)
                self.drag.Show()
                self.editor.beginDragSprite(data)

    def onQuit(self, e):
        self.Close()

    def OnSliderScroll(self, event):
        obj = event.GetEventObject()
        value = obj.GetValue()        
        self.editor.setFrame(value)

    def onAddFrame(self, event):
        self.editor.addFrame()
        p = self.sld.GetRange()
        self.sld.SetMax(p[1] + 1)

    def onRelease(self, event):
        if self.drag:
            self.drag.EndDrag()
            r = self.editor.GetRect()
            if r.Contains(event.GetPosition()):
                self.editor._onRelease(self._drag)
                if self._drag == 1:
                    self.editor.endDragTile()
                else:
                    self.editor.endDragSprite()
            self.drag = None
            self._tile = None
            self.onEditor = None

    def onMotion(self,event):
        if self.drag:
            self.drag.Move(event.GetPosition())
            r = self.editor.GetRect()
            if r.Contains(event.GetPosition()):
                self.onEditor = True
                p = event.GetPosition() - r.GetTopLeft()
                if self._drag == 1:
                    self.editor.moveTile(p)
                else:
                    self.editor.moveSprite(p)
            elif self.onEditor:
                self.onEditor = False
                self.editor._onLeave(self._drag)


###############################################################################
#
#
def main():
    """
    """
    app = wx.App()
    ex = Animator(None)
    ex.Show()
    app.MainLoop()


if __name__ == '__main__':
    main()