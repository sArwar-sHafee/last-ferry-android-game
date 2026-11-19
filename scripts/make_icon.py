"""Draw the beacon's enamel harbor mark at launcher resolution."""
from pathlib import Path
from PIL import Image, ImageDraw
root = Path(__file__).resolve().parents[1] / "game/art"
size = 864
bg = Image.new("RGB", (size, size), "#192e32")
fg = Image.new("RGBA", bg.size)
d = ImageDraw.Draw(fg)
gold = "#e8bc76"
ivory = "#e3e4ce"
d.polygon([(470,380),(670,317),(669,397)],fill="#c89959")
d.polygon([(390,378),(227,355),(231,301)],fill="#997c51")
d.polygon([(377,345),(432,299),(488,345)],fill=ivory)
d.rectangle((391,354,473,398),fill=gold)
for x in (400,430,462): d.rectangle((x,354,x+6,399),fill="#253637")
d.polygon([(382,405),(482,405),(505,552),(359,552)],fill=ivory)
d.polygon([(408,434),(456,434),(459,454),(406,454)],fill="#283d3e")
for y,w in [(567,191),(586,153),(605,93)]:
    d.rounded_rectangle((432-w//2,y,432+w//2,y+6),3,fill=gold)
fg.resize((432,432),Image.Resampling.LANCZOS).save(root/"beacon_foreground.png")
bg.resize((432,432)).save(root/"beacon_background.png")
bg.paste(fg,mask=fg.getchannel("A"))
bg.crop((155,155,709,709)).resize((256,256),Image.Resampling.LANCZOS).save(root/"beacon.png")
