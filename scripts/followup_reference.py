"""Independent follow-up oracles over synthetic deterministic inputs."""
import collections,copy,hashlib,json,math,random,subprocess
from pathlib import Path
root=Path(__file__).resolve().parents[1]
random.seed(20261018)
def run(request, error=False):
    result=subprocess.run(['node',str(root/'_build/js/debug/build/cmd/main/main.js'),'-'],input=json.dumps(request),capture_output=True,text=True,encoding='utf-8',timeout=60)
    if error:
        assert result.returncode==1,(result.returncode,result.stdout); return
    assert result.returncode in (0,2),(result.returncode,result.stdout,result.stderr)
    return json.loads(result.stdout)

for _ in range(15):
    a,b=random.randrange(-10,10),random.randrange(-10,10)
    old={'rules':[{'id':'r','when':f'x >= {a}','output':'pass'}],'default':'review'}
    new={'rules':[{'id':'r','when':f'x >= {b}','output':'pass'}],'default':'review'}
    cases=[{'id':str(x),'facts':{'x':x}} for x in range(-12,13)]
    result=run({'operation':'replay_versions','old':old,'new':new,'cases':cases})
    expected=[(x>=a)!=(x>=b) for x in range(-12,13)]
    assert result['changed_count']==sum(expected)
    assert [r['decision_changed'] for r in result['cases']]==expected
    assert not result['global_equivalence_proven']
print('Policy replay: 15 rule pairs, 375 independent threshold decisions passed')
