"""Genera el mapa reproducible del Mundo 3 (565x25 = 9.040 px + arena 960 px)."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "godot" / "data" / "world3"

def stars_for(a, b, y=18, step=4):
    return [{"x": x, "y": y - (x // step) % 2} for x in range(a, b, step)]

def enemy(t, x, y=20, reach=8):
    return {"type": t, "x": x, "y": y, "patrol": [x-reach, x+reach]}

background = {
    "sky":"w3_sky", "far":"w3_clouds_far", "near":"w3_clouds_near",
    "atlas":"world3_bg", "objectsAtlas":"world3_objects", "sparkles":True,
    "drifters":["cloud_plush"],
    "layers":[
        {"scroll":[0.01,0.02],"depth":2,"items":[{"frame":"bg_reference","x":240,"y":135,"scale":1.0,"alpha":0.7}]},
        {"scroll":[0.04,0.04],"depth":3,"frames":["bg_moon","bg_window"],"step":760,"y":[30,75],"alpha":0.9},
        {"scroll":[0.13,0.05],"depth":4,"frames":["bg_mobile","bg_teddy"],"step":420,"y":[20,160],"alpha":0.85,"sway":True}
    ]
}

terrain=[]
for x,w,y in [(0,35,20),(39,39,20),(82,35,20),(122,42,19),(169,36,20),(211,39,20),(255,34,19),(294,45,20),(344,38,19),(387,42,20),(434,43,19),(482,40,20),(527,38,19)]:
    terrain.append({"x":x,"y":y,"w":w,"h":25-y})

clouds=[]
for x,y,f in [(36,17,"pillow_pink"),(79,16,"pillow_blue"),(119,15,"cloud_plush"),(165,16,"pillow_pink"),(205,14,"rope_mid"),(251,16,"pillow_blue"),(290,13,"cloud_plush"),(340,15,"pillow_pink"),(383,12,"cloud_plush"),(430,15,"pillow_blue"),(478,14,"pillow_pink"),(523,13,"cloud_plush")]:
    clouds.append({"x":x,"y":y,"frame":f})

movers=[
    {"x":185,"y":15,"frame":"pillow_blue","dx":7,"dy":0,"duration":2600},
    {"x":228,"y":16,"frame":"pillow_pink","dx":0,"dy":-6,"duration":2300},
    {"x":306,"y":17,"frame":"cloud_plush","dx":8,"dy":-2,"duration":3000},
    {"x":400,"y":14,"frame":"pillow_blue","dx":0,"dy":-7,"duration":2500},
    {"x":451,"y":16,"frame":"pillow_pink","dx":7,"dy":0,"duration":2800,"active":False}
]

level={
    "id":3,"key":"world3","name":"El Reino de los Peluches Dormilones","widthTiles":565,"heightTiles":25,
    "music":"world3","tileset":"world3_tiles","objectsAtlas":"world3_objects","backgroundAtlas":"world3_bg",
    "progress":{"total":10000,"offset":0,"scale":1},"playerStart":{"x":3,"y":20},"nextScene":"Boss3",
    "startWeapons":["bubble","paint","sling"],
    "frames":{"flag":"flag_w3","signpost":"rabbit_plush","star":["world3_objects","star_w3"]},
    "sections":[{"id":"A","name":"El rincón de los juguetes","from":0},{"id":"B","name":"Los puentes de lana","from":1700},{"id":"C","name":"Las almohadas flotantes","from":3500},{"id":"D","name":"El laberinto de las mantas","from":5500},{"id":"E","name":"El castillo de los sueños","from":7800}],
    "background":background,"terrain":terrain,
    "blocks":[{"x":x,"y":18,"type":["block_pink","block_blue","block_star","block_heart"][i%4]} for i,x in enumerate([18,19,20,91,92,137,138,270,271,359,360,498,499])],
    "clouds":clouds,"bridges":[],"rulers":[],"movers":movers,
    "swings":[{"x":112,"y":12,"frame":"rope_mid","radius":52,"duration":2800},{"x":146,"y":11,"frame":"rope_mid","radius":44,"duration":2400},{"x":366,"y":11,"frame":"rope_mid","radius":58,"duration":3000},{"x":420,"y":10,"frame":"rope_mid","radius":48,"duration":2600}],
    "crumbles":[{"x":x,"y":y,"frame":"cloud_plush"} for x,y in [(238,13),(244,12),(275,13),(281,12)]],
    "pads":[{"x":x,"y":y,"frame":f,"power":p} for x,y,f,p in [(27,20,"pillow_pink",-500),(67,20,"pillow_blue",-470),(315,20,"pillow_pink",-520),(463,19,"pillow_blue",-490)]],
    "winds":[{"x":260,"y":8,"w":5,"h":12,"vx":12,"vy":-85},{"x":325,"y":9,"w":4,"h":11,"vx":-8,"vy":-75}],
    "hazards":[],"paints":[],"rollers":[],"bouncers":[],"drips":[],"rivers":[],"magicCrayons":[],
    "yarnRollers":[{"x":x,"y":y,"range":[a,b],"speed":s} for x,y,a,b,s in [(132,19,124,160,55),(178,20,170,203,65),(354,19,346,379,72),(443,19,436,474,60)]],
    "sleepClouds":[{"x":x,"y":y,"w":w,"duration":2400} for x,y,w in [(264,15,4),(326,16,5),(408,15,4),(505,15,5)]],
    "magicButtons":[{"x":447,"y":19,"frame":"button_pink","targetMover":4}],
    "dreamCollectibles":[
        {"id":"moon_1","kind":"moon","x":96,"y":15,"frame":"moon_w3"},{"id":"moon_2","kind":"moon","x":280,"y":10,"frame":"moon_w3"},{"id":"moon_3","kind":"moon","x":425,"y":8,"frame":"moon_w3"},
        {"id":"button_gold","kind":"button","x":190,"y":13,"frame":"button_pink"},{"id":"gift_1","kind":"regalo","x":374,"y":9,"frame":"pillow_pink"},{"id":"key_1","kind":"llave","x":512,"y":13,"frame":"button_blue"}
    ],
    "stars":sum([stars_for(5,110),stars_for(112,215,17),stars_for(218,340,16),stars_for(342,480,17),stars_for(482,557,16)],[]),
    "enemies":[enemy("rabbit",x) for x in [48,88,142,320,390,468,535]] + [enemy("wool",x) for x in [128,176,348,420,505]] + [enemy("pillow",x,14,10) for x in [230,270,302,370,455,520]],
    "checkpoints":[{"x":109,"y":20},{"x":354,"y":19}],"pickups":[],
    "signs":[{"x":5,"y":20,"text":"Mundo 3: El Reino de los Peluches Dormilones"},{"x":24,"y":20,"text":"Las almohadas elásticas te impulsan suavemente"},{"x":108,"y":20,"text":"Los puentes de lana se balancean: espera su ritmo"},{"x":258,"y":19,"text":"Las nubes violetas dan sueño, pero no quitan el control"},{"x":445,"y":19,"text":"Pulsa el botón mágico para despertar la plataforma"},{"x":540,"y":19,"text":"El Castillo de los Sueños: Rey Siestón te espera"}],
    "decor":[{"x":x,"y":y,"frame":f,"front":front} for x,y,f,front in [(10,20,"rabbit_plush",False),(31,20,"yarn_pink",True),(70,20,"pillow_blue",False),(100,20,"rabbit_plush",False),(153,19,"yarn_pink",True),(220,20,"pillow_pink",False),(288,19,"rabbit_plush",False),(337,20,"yarn_pink",True),(410,20,"rabbit_plush",False),(475,19,"pillow_blue",False),(530,19,"yarn_pink",True)]],
    "door":{"x":558,"y":19,"atlas":"world3_objects","frame":"portal_w3","scale":1.0}
}

boss={
    "key":"world3_boss","worldId":3,"widthTiles":60,"heightTiles":17,"music":"world3","bossMusic":"sieston",
    "tileset":"world3_tiles","objectsAtlas":"world3_objects","backgroundAtlas":"world3_bg","background":background,
    "frames":level["frames"],"progress":{"total":10000,"offset":9040,"scale":1},"playerStart":{"x":2,"y":14},
    "sections":[{"id":"E","name":"El castillo de los sueños","from":7800}],
    "terrain":[{"x":0,"y":14,"w":60,"h":3}],"blocks":[],"clouds":[{"x":15,"y":10,"frame":"pillow_pink"},{"x":44,"y":10,"frame":"pillow_blue"}],
    "bridges":[],"rulers":[],"movers":[],"swings":[],"crumbles":[],"pads":[],"winds":[],"hazards":[],"stars":[{"x":x,"y":13} for x in [12,13,14,45,46,47]],
    "enemies":[],"checkpoints":[],"pickups":[],"signs":[],"decor":[{"x":3,"y":14,"frame":"rabbit_plush"},{"x":30,"y":14,"frame":"yarn_pink","front":True},{"x":57,"y":14,"frame":"pillow_blue"}],
    "gate":{"x":5,"rows":[10,11,12,13],"tile":"block_star"},"triggerX":9,
    "boss":{"homeX":34,"minX":8,"maxX":58,"floorY":224,"frameBoth":True,"scene":"res://scenes/bosses/ReySieston.tscn","name":"Rey Siestón","introBanner":"¡Rey Siestón, el Rey de los Peluches Dormilones!","defeatBanner":"¡El reino vuelve a dormir en paz!","portalToast":"El portal al Mundo 4 está preparado","afterMusic":"world3"},
    "portal":{"x":57,"y":14}
}

OUT.mkdir(parents=True, exist_ok=True)
for name,data in [("world3.json",level),("world3_boss.json",boss)]:
    (OUT/name).write_text(json.dumps(data,ensure_ascii=False,indent=1)+"\n",encoding="utf-8")
print(f"Mundo 3: {len(level['stars'])} estrellas, {len(level['enemies'])} enemigos, ancho total 10000 px")
