import json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'scripts/campaign/data'
def dump(name, data):
    (OUT / name).write_text(json.dumps(data, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
enemies = {}
def add(id,name,weapon,hp,speed,length,damage,spin,cd,weight=2,ww=2,ranged=False,**extra):
    enemies[id]=dict(name=name,weapon=weapon,hp=hp,speed=speed,length=length,damage=damage,spin=spin,cooldown=cd,weight=weight,weapon_weight=ww,ranged=ranged,**extra)
add('fencer','Рапирист','rapier',12,350,45,1,5.2,.9,0,0)
add('spearman','Копейщик','spear',14,290,65,1,3.3,1.5)
add('axe','Секира','axe',15,285,42,2,3.2,1.6,2,4,impact=155)
add('shield','Щитоносец','shield',18,250,28,1,3.2,1.3,3,2)
add('crossbow','Арбалетчик','crossbow',12,275,40,2,0,2.8,0,2,True)
add('hammer','Молотобоец','hammer',18,235,45,2,2.4,2.4,4,4,impact=180)
add('flail','Цепник','flail',18,280,60,2,3.4,1.4,2,4)
add('boomerang','Бумеранг','boomerang',16,310,75,2,0,2.5,0,0,True)
add('chakram','Чакрам','chakram',17,300,42,2,5.5,1.1,0,0)
add('harpoon','Гарпунщик','harpoon',20,280,58,2,3.2,2.8)
add('sickle','Жнец','sickle',16,310,45,1,4.4,1.1,1,0)
add('trident','Трезубец','trident',19,290,57,2,3.5,1.5)
add('alchemist','Алхимик','flask',18,270,35,1,0,4.8,0,0,True)
add('pyro','Пиромант','fireball',17,290,40,2,0,3,2,0,True)
add('cryo','Криомант','iceball',17,280,40,1,0,3,2,0,True)
add('magnet','Магнетик','magnet',20,260,45,1,0,6,3,4,True)
dump('enemies.json',enemies)
add('bridge_guard','Страж переправы','spear',34,260,62,2,3.6,1.4,3,2,boss='guard',size=1.1)
add('chain_maestro','Маэстро цепей','flail',43,280,75,3,3.5,1.6,3,4,boss='chain',size=1.1)
add('storm_crossbow','Штормовой арбалетчик','crossbow',51,305,40,3,0,2.5,2,2,True,boss='storm')
add('nox','Алхимик Нокс','flask',63,270,40,3,0,3.8,2,0,True,boss='nox')
add('magnetic_archon','Магнитный Архонт','magnet',76,250,50,4,0,6,4,4,True,boss='archon',size=1.3)
dump('enemies.json',enemies)
tables = [
 [('fencer',12,1),('axe',14,2),('spearman',13,1),('shield',17,1),('crossbow',12,2),[('fencer',11,1),('axe',10,1)],('hammer',18,2),('sickle',16,1),[('spearman',15,2),('shield',16,1)],('bridge_guard',34,2)],
 [('crossbow',17,2),('flail',19,2),('boomerang',17,2),[('axe',16,2),('fencer',14,1)],('chakram',20,2),('harpoon',22,2),[('shield',20,1),('crossbow',16,2)],[('hammer',21,3),('flail',19,2)],[('harpoon',24,2),('chakram',18,2)],('chain_maestro',43,3)],
 [('sickle',24,2),('trident',23,2),('alchemist',18,1),[('trident',21,2),('crossbow',17,2)],('pyro',20,2),[('harpoon',23,2),('hammer',24,3)],('cryo',21,1),[('sickle',23,2),('boomerang',21,2)],[('chakram',24,2),('pyro',21,2)],('storm_crossbow',51,3)],
 [('magnet',25,1),[('trident',26,3),('flail',25,2)],[('alchemist',24,2),('shield',27,1)],[('cryo',25,2),('axe',26,3)],('pyro',30,3),[('magnet',27,1),('crossbow',24,3)],[('chakram',28,3),('sickle',26,2)],[('harpoon',29,2),('alchemist',25,1)],[('hammer',32,4),('pyro',27,2)],('nox',63,3)],
 [[('cryo',32,2),('fencer',27,3)],[('flail',31,3),('crossbow',28,3)],[('pyro',31,3),('shield',33,2)],[('magnet',33,2),('sickle',30,2)],[('chakram',35,3),('trident',36,3)],[('alchemist',36,2),('crossbow',30,3)],[('hammer',38,4),('magnet',32,2)],[('boomerang',35,3),('cryo',33,2)],[('harpoon',37,3),('pyro',35,3)],('magnetic_archon',76,4)]
]
names=['Арена новичков','Оружейный двор','Кровь и алхимия','Лаборатория хаоса','Магнитный разлом']
def distribute(total):
    weights=list(range(7,16))+[24]
    amounts=[int(total*w/sum(weights)) for w in weights]
    for i in range(total-sum(amounts)): amounts[9-i%10]+=1
    return amounts
levels=[]
for level, (table,name,coins,xp) in enumerate(zip(tables,names,[140,220,310,420,550],[75,115,160,215,280]),1):
    c,x=distribute(coins),distribute(xp)
    fights=[]
    for battle,entry in enumerate(table,1):
        entries=entry if isinstance(entry,list) else [entry]
        fights.append(dict(battle=battle,boss=battle==10,enemies=[dict(id=e[0],hp=e[1],damage=e[2]) for e in entries],reward=dict(coins=c[battle-1],xp=x[battle-1])))
    levels.append(dict(level=level,name=name,battles=fights))
dump('levels.json',levels)
