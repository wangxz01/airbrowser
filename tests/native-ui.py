"""Developer-only UI inspection for an explicitly selected emulator target."""
import argparse
import json
import re
import subprocess
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--target', required=True)
parser.add_argument('action', choices=['dump', 'click-text', 'input', 'key', 'click', 'shot'])
parser.add_argument('values', nargs='*')
args = parser.parse_args()
root = Path(__file__).resolve().parent.parent
hdc = '/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc'
def run(*parts):
    return subprocess.check_output([hdc, '-t', args.target, *map(str,parts)], text=True)
def layout():
    run('shell', 'uitest', 'dumpLayout', '-b', 'com.adam.airbrowser', '-p', '/data/local/tmp/air-ui.json')
    target = root/'artifacts/native-layout.json'
    run('file','recv','/data/local/tmp/air-ui.json',target)
    tree = json.loads(target.read_text())
    nodes=[]
    def walk(node):
        a=node.get('attributes',{})
        if a.get('text') or a.get('type') in ['Button','TextInput','Web','Video']:
            nodes.append({k:a.get(k) for k in ['type','text','accessibilityText','bounds','enabled','focused']})
        for c in node.get('children',[]): walk(c)
    walk(tree)
    return nodes
if args.action=='dump':
    print(json.dumps(layout(),ensure_ascii=False,indent=2))
elif args.action=='click-text':
    matches=[n for n in layout() if n['text']==args.values[0] and n['type']!='staticText']
    if len(matches)!=1: raise SystemExit(f'Expected one text match, found {len(matches)}')
    x1,y1,x2,y2=map(int,re.findall(r'\d+',matches[0]['bounds']))
    print(run('shell','uitest','uiInput','click',(x1+x2)//2,(y1+y2)//2))
elif args.action=='input':
    inputs=[n for n in layout() if n['type']=='TextInput']
    if len(inputs)!=1: raise SystemExit('Address input is ambiguous')
    x1,y1,x2,y2=map(int,re.findall(r'\d+',inputs[0]['bounds']))
    run('shell','uitest','uiInput','click',(x1+x2)//2,(y1+y2)//2)
    run('shell','uitest','uiInput','keyEvent','2072','2017')
    run('shell','uitest','uiInput','keyEvent','2055')
    print(run('shell','uitest','uiInput','inputText',(x1+x2)//2,(y1+y2)//2,args.values[0]))
    print(run('shell','uitest','uiInput','keyEvent','2054'))
elif args.action=='key': print(run('shell','uitest','uiInput','keyEvent',*args.values))
elif args.action=='click': print(run('shell','uitest','uiInput','click',*args.values))
elif args.action=='shot':
    name=args.values[0] if args.values else 'native.png'
    if Path(name).name!=name: raise SystemExit('Use a file name, not a path')
    run('shell','uitest','screenCap','-p','/data/local/tmp/air-screen.png')
    print(run('file','recv','/data/local/tmp/air-screen.png',root/'artifacts'/name))
