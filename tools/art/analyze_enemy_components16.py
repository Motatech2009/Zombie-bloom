import json, struct, sys, array
from pathlib import Path
def load_glb(p):
 b=Path(p).read_bytes();n=struct.unpack_from("<I",b,12)[0];j=json.loads(b[20:20+n]);binstart=20+n+8
 def read(a):
  acc=j["accessors"][a];v=j["bufferViews"][acc["bufferView"]];offset=binstart+v.get("byteOffset",0)+acc.get("byteOffset",0)
  types={5126:"f",5125:"I",5123:"H"};dims={"SCALAR":1,"VEC2":2,"VEC3":3,"VEC4":4};typ=types[acc["componentType"]];dim=dims[acc["type"]];size=struct.calcsize("<"+typ)*dim;stride=v.get("byteStride",size)
  return [struct.unpack_from("<"+typ*dim,b,offset+i*stride) for i in range(acc["count"])]
 primitive=j["meshes"][0]["primitives"][0]
 pos=read(primitive["attributes"]["POSITION"]);ids=[x[0] for x in read(primitive["indices"])]
 return pos,ids
for arg in sys.argv[1:]:
 path=Path(arg);pos,ids=load_glb(path);parents=list(range(len(pos)))
 def find(a):
  while parents[a]!=a:parents[a]=parents[parents[a]];a=parents[a]
  return a
 def union(a,b):parents[find(a)]=find(b)
 weld={}
 for i,p in enumerate(pos):
  key=tuple(round(x*100000) for x in p)
  if key in weld:union(i,weld[key])
  else:weld[key]=i
 for i in range(0,len(ids),3):union(ids[i],ids[i+1]);union(ids[i],ids[i+2])
 labels=[find(i) for i in range(len(pos))];groups={}
 for i in range(0,len(ids),3):
  key=labels[ids[i]]
  c=groups.setdefault(key,{"id":key,"triangles":0,"min":[float("inf")]*3,"max":[-float("inf")]*3})
  c["triangles"]+=1
  for k in ids[i:i+3]:
   for axis in range(3):c["min"][axis]=min(c["min"][axis],pos[k][axis]);c["max"][axis]=max(c["max"][axis],pos[k][axis])
 comps=sorted(groups.values(),key=lambda c:-c["triangles"])
 for c in comps:c["center"]=[(a+b)*.5 for a,b in zip(c["min"],c["max"])]
 path.with_suffix(".components.json").write_text(json.dumps({"vertices":len(pos),"triangles":len(ids)//3,"components":comps},indent=2))
 path.with_suffix(".components.bin").write_bytes(array.array("I",labels).tobytes())
 print(json.dumps({"name":path.stem,"count":len(comps),"top":comps[:36]},ensure_ascii=False))
