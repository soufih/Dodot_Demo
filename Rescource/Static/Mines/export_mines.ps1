#requires -PSEdition Desktop
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Collections.Generic;
using System.IO;
public static class MineExporter {
 public static void Run(string source, string materials, string output) {
  string[] ids={"296","301","302","303","304","305","306","311","312","313","314","320","329","341"};
  using(var src=new Bitmap(source)) using(var atlas=new Bitmap(224,64,PixelFormat.Format32bppArgb)) using(var preview=new Bitmap(896,256,PixelFormat.Format32bppArgb)) {
   for(int n=0;n<ids.Length;n++) {
    int col=n%7,row=n/7,x0=(int)Math.Round(col*src.Width/7.0),x1=(int)Math.Round((col+1)*src.Width/7.0),y0=row*src.Height/2,y1=(row+1)*src.Height/2;
    int left=x1,top=y1,right=x0,bottom=y0;
    for(int y=y0;y<y1;y++) for(int x=x0;x<x1;x++) if(src.GetPixel(x,y).A>=200) {left=Math.Min(left,x);right=Math.Max(right,x);top=Math.Min(top,y);bottom=Math.Max(bottom,y);}
    var palette=new List<Color>();
    foreach(string id in new[]{ids[n],"306"}) using(var reference=new Bitmap(Path.Combine(materials,"item"+id+".png"))) {
     for(int y=0;y<reference.Height;y++) for(int x=0;x<reference.Width;x++) {var c=reference.GetPixel(x,y);if(c.A>=200&&!palette.Exists(p=>p.ToArgb()==c.ToArgb())) palette.Add(Color.FromArgb(255,c.R,c.G,c.B));}
    }
    int w=right-left+1,h=bottom-top+1;double scale=28.0/Math.Max(w,h);int dw=(int)Math.Round(w*scale),dh=(int)Math.Round(h*scale),ox=(32-dw)/2,oy=30-dh;
    using(var sprite=new Bitmap(32,32,PixelFormat.Format32bppArgb)) {
     for(int y=0;y<dh;y++) for(int x=0;x<dw;x++) {
      var c=src.GetPixel(left+Math.Min(w-1,(int)((x+0.5)*w/dw)),top+Math.Min(h-1,(int)((y+0.5)*h/dh)));if(c.A<200)continue;
      Color best=palette[0];int distance=int.MaxValue;
      foreach(var p in palette) {int dr=c.R-p.R,dg=c.G-p.G,db=c.B-p.B,d=dr*dr+dg*dg+db*db;if(d<distance){distance=d;best=p;}}
      sprite.SetPixel(ox+x,oy+y,best);
     }
     sprite.Save(Path.Combine(output,"mine_item"+ids[n]+".png"),ImageFormat.Png);
     for(int y=0;y<32;y++) for(int x=0;x<32;x++) {var c=sprite.GetPixel(x,y);atlas.SetPixel(col*32+x,row*32+y,c);for(int py=0;py<4;py++)for(int px=0;px<4;px++)preview.SetPixel((col*32+x)*4+px,(row*32+y)*4+py,c);}
    }
   }
   atlas.Save(Path.Combine(output,"mines_atlas_32.png"),ImageFormat.Png);
   preview.Save(Path.Combine(output,"mines_preview_4x.png"),ImageFormat.Png);
  }
 }
}
'@
$mineSource = Join-Path $PSScriptRoot 'source\mines_generated.png'
$materialDirectory = Join-Path (Split-Path $PSScriptRoot -Parent) 'Material'
[MineExporter]::Run($mineSource, $materialDirectory, $PSScriptRoot)
