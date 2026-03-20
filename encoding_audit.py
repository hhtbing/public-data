import os, sys
fail = 0
warn = 0
exts = ('.html','.css','.js','.jsx','.ts','.tsx','.vue','.json','.md','.yml','.yaml','.sh','.ps1')
for root, dirs, files in os.walk('.'):
    if any(p in root for p in ['.git', '.github', '.venv', 'node_modules', 'vendor', 'dist', 'build', '__pycache__']):
        continue
    for f in files:
        if f.endswith(exts):
            p = os.path.join(root, f)
            with open(p, 'rb') as b:
                data = b.read()
            try:
                data.decode('utf-8')
            except Exception as e:
                print('ERR', p, e)
                fail += 1
                continue
            if data.startswith(b'\xef\xbb\xbf') and not f.endswith('.ps1'):
                print('WARN BOM', p)
                warn += 1
            if b'\r\n' in data:
                print('WARN CRLF', p)
                warn += 1
print('RESULT errors=%d warnings=%d' % (fail,warn))
if fail:
    sys.exit(1)
