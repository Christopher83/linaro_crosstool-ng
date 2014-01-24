import fileinput
import pprint

packages = []
package = {}

for line in fileinput.input():
    line = line.strip()

    if not line:
        if package:
            packages.append(package)

        package = {}
    elif ':' in line:
        parts = line.split(':', 1)
        name, value = parts
        value = value.strip()

        if name == 'Depends':
            value = [x.strip().split()[0] for x in value.split(',')]

        package[name] = value

for package in packages:
    depends = package.get('Depends', [])

    if 'libstdc++6' in depends:
        print len(depends), package['Package'], depends


