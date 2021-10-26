#! /usr/bin/env python3

"""
Helper functions for validating schemas and resources using the Frictionless framework
"""


import sys

from frictionless import Resource, Layout, validate, FrictionlessException


def resource_valid(resouce:[str, Resource]):
    """
    Validate the given resource (including data accessed from the specified path)

    :param resouce: frictionless.Resource object, path to a resource file
    :return: tuple (valid:bool, errors:list)
    """
    if not isinstance(resouce, Resource):
        try:
            resource = Resource(resouce)
        except FrictionlessException as e:
            return False, [f"Not a valid resource description:\n{e}"]

    try:
        report = validate(resource)
    except FrictionlessException as e:
        return False, [f"An exception occurred during validation:\n{e}"]

    return report.valid, report.flatten(['name', 'message'])


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print('Usage: {} resource.yaml ...'.format(*sys.argv))

    invalid = []
    for res in sys.argv[1:]:
        print('\n{} ... '.format(res), end='')
        valid, errors = resource_valid(res)
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

    exit(len(invalid))
