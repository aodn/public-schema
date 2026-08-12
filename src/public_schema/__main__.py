"""CLI entry point: python -m public_schema <resource.yaml> ..."""

import sys

from public_schema.validate import validate_resource


def main():
    if len(sys.argv) < 2:
        print('Usage: python -m public_schema resource.yaml ...')
        sys.exit(1)

    invalid = []
    for res in sys.argv[1:]:
        print('\n{} ... '.format(res), end='')
        valid, errors = validate_resource(res)
        if valid:
            print('ok')
        else:
            print('invalid!')
            print(*errors[:5], sep='\n')
            if len(errors) > 5:
                print('... ({} errors)'.format(len(errors)))
            invalid.append(res)

    if invalid:
        print('\n', 55*'-', 'Invalid resources:', *invalid, 55*'-', sep='\n')

    sys.exit(len(invalid))


if __name__ == '__main__':
    main()
