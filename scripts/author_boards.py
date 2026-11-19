"""Build the fixed station schematics and their independently replayable solutions.

These are design-time tools. The game ships authored, stable boards in schematics.json.
"""
from collections import deque

import json
import random
from pathlib import Path

DIR = [(0,-1),(1,0),(0,1),(-1,0)]

def path(start, won, neighbors, limit=120000):
    todo, parents = deque([start]), {start: None}
    while todo and len(parents) < limit:
        state = todo.popleft()
        if won(state):
            steps = []
            while parents[state]:
                state, step = parents[state]
                steps.append(step)
            return steps[::-1]
        for step, nxt in neighbors(state):
            if nxt not in parents:
                parents[nxt] = state, step
                todo.append(nxt)
    return []

def slide(seed, depth):
    rng = random.Random(seed)
    for attempt in range(100000):
        pieces = [(rng.randrange(0,3),2,1,2)]
        used = {(pieces[0][0],2),(pieces[0][0]+1,2)}
        for _ in range(38):
            horizontal = rng.randrange(2)
            length = rng.choice((2,2,2,3))
            x = rng.randrange(7-length if horizontal else 6)
            y = rng.randrange(6 if horizontal else 7-length)
            if horizontal and y == 2:
                continue
            cells = {(x+i*horizontal,y+i*(1-horizontal)) for i in range(length)}
            if used.isdisjoint(cells):
                used.update(cells)
                pieces.append((x,y,horizontal,length))
            if len(pieces) >= min(13,6+depth): break
        starts = tuple(x+y*6 for x,y,_,_ in pieces)
        offsets = [[i*(1 if h else 6) for i in range(n)] for _,_,h,n in pieces]
        def moves(state):
            occupied = {pos+d for pos,ds in zip(state,offsets) for d in ds}
            for i,(pos,ds) in enumerate(zip(state,offsets)):
                stride = ds[1]
                for sign in (-1,1):
                    end = pos if sign == -1 else pos+ds[-1]
                    while True:
                        nxt = end + sign*stride
                        if not 0 <= nxt < 36 or (stride == 1 and nxt//6 != end//6) or nxt in occupied: break
                        end = nxt
                        newpos = end if sign == -1 else end-ds[-1]
                        yield [i,newpos], state[:i]+(newpos,)+state[i+1:]
        solution = path(starts, lambda s:s[0]==16,moves,12000)
        if len(solution)>=depth:
            return dict(kind="slip",w=6,h=6,pieces=[[s,h,l] for s,(_,_,h,l) in zip(starts,pieces)],solution=solution)
    raise RuntimeError("Slip not found")

def water(cap, target_depth, seed):
    rng = random.Random(seed)
    start = tuple([cap[0]]+[0]*(len(cap)-1))
    def moves(s):
        for a in range(len(cap)):
            for b in range(len(cap)):
                if a==b: continue
                amount = min(s[a], cap[b]-s[b])
                if amount:
                    n = list(s); n[a]-=amount; n[b]+=amount
                    yield [a,b],tuple(n)
    todo=deque([(start,[])]); seen={start}; choices=[]
    while todo:
        s,steps=todo.popleft()
        if len(steps)>=target_depth and sum(v>0 for v in s)>=2: choices.append((s,steps))
        for step,n in moves(s):
            if n not in seen:
                seen.add(n);todo.append((n,steps+[step]))
    target, solution = rng.choice(choices)
    return dict(kind="sluice",cap=cap,start=start,goal=target,solution=solution)

def freight(rows):
    w=len(rows[0]); h=len(rows)
    walls={i for i,c in enumerate(''.join(rows)) if c=='#'}
    goals=sorted(i for i,c in enumerate(''.join(rows)) if c in '.*+')
    boxes=tuple(i for i,c in enumerate(''.join(rows)) if c in '$*')
    p=next(i for i,c in enumerate(''.join(rows)) if c in '@+')
    def moves(s):
        p,boxes=s
        for d,off in enumerate((-w,1,w,-1)):
            n=p+off
            if n in walls or n<0 or n>=w*h or (d%2 and n//w!=p//w): continue
            b=list(boxes)
            if n in boxes:
                k=n+off
                if k in walls or k in boxes or k<0 or k>=w*h or (d%2 and k//w!=n//w): continue
                b[b.index(n)]=k
            yield d,(n,tuple(sorted(b)))
    sol=path((p,boxes),lambda s:list(s[1])==goals,moves)
    if not sol:raise ValueError(rows)
    return dict(kind="freight",w=w,h=h,walls=sorted(walls),targets=goals,boxes=boxes,worker=p,solution=sol)

def pipes(seed,w,h):
    rng=random.Random(seed)
    masks=[0]*(w*h)
    source=(h//2)*w
    seen={source}
    def grow(cell):
        directions=list(range(4));rng.shuffle(directions)
        for d in directions:
            dx,dy=DIR[d];x=cell%w+dx;y=cell//w+dy;n=x+y*w
            if 0<=x<w and 0<=y<h and n not in seen:
                seen.add(n);masks[cell]|=1<<d;masks[n]|=1<<((d+2)%4);grow(n)
    grow(source)
    fixed=[source]
    starts=masks.copy()
    sol=[]
    for i,mask in enumerate(masks):
        if i in fixed: continue
        for _ in range(rng.randrange(4)): starts[i]=((starts[i]<<1)&15)|(starts[i]>>3)
        m=starts[i]
        while m!=mask:
            sol.append(i);m=((m<<1)&15)|(m>>3)
    return dict(kind="pump",w=w,h=h,start=starts,source=source,fixed=fixed,solution=sol)

def optics(seed,w,h,turns):
    rng=random.Random(seed)
    for _ in range(15000):
        entry=rng.randrange(h)*w
        d=1; route=[];mirrors={};cell=entry
        while True:
            if cell in route:break
            route.append(cell);x,y=cell%w,cell//w
            if len(route)>1 and len(mirrors)<turns and rng.random()<0.45:
                choices=[]
                for tilt in (0,1):
                    nd=(d^1) if tilt==0 else (3-d)
                    dx,dy=DIR[nd];nx,ny=x+dx,y+dy
                    if 0<=nx<w and 0<=ny<h and nx+ny*w not in route:choices.append((tilt,nd))
                if choices:
                    tilt,d=rng.choice(choices); mirrors[cell]=tilt
            dx,dy=DIR[d];nx,ny=x+dx,y+dy
            if not (0<=nx<w and 0<=ny<h):
                if d==1 and len(mirrors)==turns and len(route)>=w+turns:
                    target=cell;others=[i for i in range(w*h) if i not in route]
                    rng.shuffle(others)
                    for k in others[:turns//2]: mirrors[k]=rng.randrange(2)
                    relays=sorted(rng.sample([i for i in route[1:-1] if i not in mirrors],min(3,len([i for i in route[1:-1] if i not in mirrors]))))
                    sol=[i for i in mirrors if i in route and rng.random()<0.75] or [next(iter(mirrors))]
                    return dict(kind="lens",w=w,h=h,entry=entry,target=target,relays=relays,mirrors=[[i,v^(i in sol)] for i,v in mirrors.items()],solution=sol)
                break
            cell=nx+ny*w
    raise ValueError("ray")

# Each cargo floor is cut to a different set of sidings and loading bays.
CARGO=[
["######","#    #","# @$.#","#    #","######"],
["#######","#  .  #","#  $  #","#  #@ #","# $.  #","#######"],
["########","#    . #","# .#   #","#  $ $ #","#   @  #","########"],
["########","# ..   #","#  #   #","#  $ $ #","#   #@ #","#      #","########"],
["########","#   .. #","# $ #  #","#  $   #","# #  $ #","# . @  #","########"],
["########","#  .   #","#  # . #","# $$   #","#  #  @#","########"],
["########","#   .  #","#  #   #","#   $$ #","# .  @ #","########"],
["########","#    . #","#  # $ #","#  .  @#","# $    #","#    # #","########"],
["########","# .   .#","# # $  #","#   #  #","#  $ $ #","# . @  #","########"],
["########","#  ..  #","# #  # #","# $$   #","#  $.  #","#    @ #","########"],
]
BOARDS = {
    's1':('s',3,2),'s2':('s',21,4),'s3':('s',44,5),'s4':('s',72,6),'s5':('s',92,7),
    's6':('s',703,6),'s7':('s',833,8),'s8':('s',333,8),
    'w1':('w',[6,4,2],2,9),'w2':('w',[8,5,3],4,18),'w3':('w',[10,7,3],6,19),
    'w4':('w',[11,7,4],7,21),'w5':('w',[12,7,5],8,57),'w6':('w',[13,8,5],9,81),
    'w7':('w',[14,9,5],9,99),'w8':('w',[15,8,5,3],7,8),'w9':('w',[17,9,5,3],8,28),
    'w10':('w',[18,11,7],10,36),'w11':('w',[19,12,7],10,201),
}
for i,rows in enumerate(CARGO): BOARDS['f'+str(i+1)]=('f',rows)
for i,(w,h) in enumerate([(3,3),(4,3),(4,4),(5,4),(5,5),(6,5),(5,4),(6,5),(6,5),(6,6)]): BOARDS['p'+str(i+1)]=('p',180+i,w,h)
for i,(w,h,t) in enumerate([(4,4,2),(5,4,2),(5,5,4),(6,5,4),(6,5,6),(7,5,6),(7,6,6),(7,6,6),(7,6,8),(8,6,8)]): BOARDS['l'+str(i+1)]=('l',666+i,w,h,t)
BOARDS.update({
    's9': ('s', 307, 9), 's10': ('s', 197, 10), 's11': ('s', 404, 11),
    'w12': ('w', [17, 10, 7], 12, 408), 'w13': ('w', [21, 13, 8], 15, 511),
    'f11': ('f', ["########", "# ..   #", "#    . #", "# #$ # #", "#  $ $ #", "#   @  #", "########"]),
    'f12': ('f', ["########", "# #  ..#", "# #  $ #", "# . $$ #", "#   #  #", "#   @  #", "########"]),
    'p11': ('p', 411, 6, 6), 'p12': ('p', 602, 7, 6),
    'l11': ('l', 147, 8, 6, 8), 'l12': ('l', 872, 8, 6, 10),
})
if __name__=='__main__':
    builders={'s':slide,'w':water,'f':freight,'p':pipes,'l':optics}
    boards={}
    for name,(kind,*args) in BOARDS.items():
        boards[name]=builders[kind](*args)
        print(name,len(boards[name]['solution']),flush=True)
    (Path(__file__).resolve().parents[1]/'game/art/schematics.json').write_text(json.dumps(boards,indent=1)+'\n')
