import inspect,sys,textwrap
if sys.argv[1]=='stable-ties':
    from vyper.venom.passes import concretize_mem_loc as m
    src=textwrap.dedent(inspect.getsource(m.ConcretizeMemLocPass.run_pass))
    old='to_allocate.sort(key=lambda x: (x[0] not in escaped, len(x[1])))'
    new='to_allocate.sort(key=lambda x: (x[0] not in escaped, len(x[1]), x[0].inst.output.value))'
    assert old in src
    exec(compile(src.replace(old,new),'<diagnostic-stable-allocation-ties>','exec'),m.__dict__)
    m.ConcretizeMemLocPass.run_pass=m.run_pass
sys.argv=sys.argv[:1]+sys.argv[2:]
from vyper.cli.vyper_compile import _parse_cli_args
_parse_cli_args()
