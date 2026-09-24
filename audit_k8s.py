import os
import yaml
import re

def is_pinned(image):
    if not image: return False
    if image.endswith(':latest'): return False
    if '@' in image: return True
    parts = image.split(':')
    if len(parts) > 1 and '/' not in parts[-1]:
        return True
    return False

def audit_resource(doc, file_path):
    kind = doc.get('kind', 'Unknown')
    name = doc.get('metadata', {}).get('name', 'Unknown')
    ns = doc.get('metadata', {}).get('namespace', 'default (implied)')
    
    report = {
        'file': file_path,
        'kind': kind,
        'name': name,
        'namespace': ns,
        'issues': []
    }

    spec = doc.get('spec', {})

    # Check Pod Templates
    containers = []
    if kind in ['Deployment', 'StatefulSet', 'DaemonSet', 'Job']:
        template = spec.get('template', {})
        containers = template.get('spec', {}).get('containers', [])
    elif kind == 'CronJob':
        template = spec.get('jobTemplate', {}).get('spec', {}).get('template', {})
        containers = template.get('spec', {}).get('containers', [])
    elif kind == 'Pod':
        containers = spec.get('containers', [])

    for c in containers:
        c_name = c.get('name', 'unknown')
        image = c.get('image', '')
        if not is_pinned(image):
            report['issues'].append(f"Container '{c_name}' uses unpinned image: {image}")
        
        resources = c.get('resources', {})
        if not resources.get('requests'):
            report['issues'].append(f"Container '{c_name}' missing resource requests")
        if not resources.get('limits'):
            report['issues'].append(f"Container '{c_name}' missing resource limits")
            
        if not c.get('livenessProbe'):
            report['issues'].append(f"Container '{c_name}' missing livenessProbe")
        if not c.get('readinessProbe'):
            report['issues'].append(f"Container '{c_name}' missing readinessProbe")
            
        # Hardcoded secrets in env?
        for env in c.get('env', []):
            # rudimentary check: if name contains SECRET, PASSWORD, TOKEN, KEY and uses 'value'
            env_name = env.get('name', '').upper()
            if any(x in env_name for x in ['SECRET', 'PASSWORD', 'TOKEN', 'KEY', 'PASS']):
                if 'value' in env and env['value']:
                    report['issues'].append(f"Container '{c_name}' has potentially hardcoded secret in env '{env_name}'")

    # Service selector
    if kind == 'Service':
        if spec.get('type') != 'ExternalName':
            if not spec.get('selector'):
                report['issues'].append("Service missing pod selector")

    # PVC storage class
    if kind == 'PersistentVolumeClaim':
        if not spec.get('storageClassName'):
            report['issues'].append("PVC missing storageClassName")

    return report

def run_audit():
    import glob
    files = glob.glob('infrastructure/k8s/**/*.yaml', recursive=True)
    files.extend(glob.glob('infrastructure/k8s/**/*.yml', recursive=True))
    
    results = []
    for f in files:
        if 'compiled' in f: continue
        with open(f, 'r') as fd:
            try:
                docs = yaml.safe_load_all(fd)
                for doc in docs:
                    if not doc: continue
                    if isinstance(doc, dict) and 'kind' in doc:
                        results.append(audit_resource(doc, f))
            except Exception as e:
                pass # skip invalid yaml (like kustomize patches sometimes)

    return results

if __name__ == '__main__':
    res = run_audit()
    for r in res:
        print(f"--- {r['kind']} {r['name']} in {r['file']} (ns: {r['namespace']}) ---")
        for iss in r['issues']:
            print(f"  - {iss}")
        if not r['issues']:
            print("  - OK")
    
    # Check SQL migrations
    print("\n--- SQL Migrations ---")
    import os
    for root, dirs, files in os.walk('infrastructure/k8s/base/sql'):
        for f in files:
            if f.endswith('.sql'):
                if re.match(r'^V\d+__[a-zA-Z0-9_]+\.sql$', f):
                    print(f"  - OK: {os.path.join(root, f)}")
                else:
                    print(f"  - INVALID NAMING: {os.path.join(root, f)}")
