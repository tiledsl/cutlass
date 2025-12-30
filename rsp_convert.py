#!/usr/bin/env python3
import os
import sys
import json
import argparse

def replace_option_files(entries: list) -> list:
    new_entries = []
    for entry in entries:
        directory = entry['directory']
        if 'command' in entry.keys():
            entry['arguments'] = entry['command'].replace('  ', ' ').split(' ')
            entry.pop('command')
        old_args = entry['arguments']
        new_args = []
        i = 0
        while i < len(old_args):
            arg = old_args[i]
            if arg == '--options-file':
                options_file = old_args[i + 1]
                rsp_file = os.path.join(directory, options_file)
                with open(rsp_file, "r") as fp:
                    rsp_content = fp.read().strip()
                assert 1 == len(rsp_content.split('\n'))
                inc_options = []
                for inc in rsp_content.split(' '):
                    # dequote -I
                    if inc.startswith('-I\"') and inc.endswith('\"'):
                        inc_options.append("-I" + inc[3:-1])
                        continue
                    inc_options.append(inc)
                new_args.extend(inc_options)
                i += 2
            else:
                new_args.append(arg)
                i += 1
        entry['arguments'] = new_args
        new_entries.append(entry)
    return new_entries

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", "-i", type=str, required=False, help="Input file, default stdin")
    parser.add_argument("--output", "-o", type=str, required=False, help="Output file, default stdout")
    args = parser.parse_args()
    if args.input:
        with open(args.input, "r") as fp:
            entries = json.load(fp)
    else:
        entries = json.load(sys.stdin)
    new_entries = replace_option_files(entries)
    if args.output:
        with open(args.output, "w") as fp:
            json.dump(new_entries, fp)
    else:
        json.dump(new_entries, sys.stdout)
