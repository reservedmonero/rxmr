#!/usr/bin/env python3

import argparse
import os
import subprocess
import sys

PROJECT_NAME = 'rXMR'
PROJECT_SLUG = 'rxmr'
DEFAULT_SOURCE_URL = 'https://github.com/happybigmtn/rXMR.git'
DEFAULT_SIGS_ENV_VARS = ('RXMR_GITIAN_SIGS_URL', 'GITIAN_SIGS_URL')
gbrepo = 'https://github.com/devrandom/gitian-builder.git'

platforms = {'l': ['Linux', 'linux', 'tar.bz2'],
        'a': ['Android', 'android', 'tar.bz2'],
        'f': ['FreeBSD', 'freebsd', 'tar.bz2'],
        'w': ['Windows', 'win', 'zip'],
        'm': ['MacOS', 'osx', 'tar.bz2'] }

def sigs_dir():
    return args.sigs_dir if os.path.isabs(args.sigs_dir) else os.path.join(workdir, args.sigs_dir)

def selected_platforms():
    seen = set()
    for key in args.os:
        if key not in platforms:
            raise Exception('Unknown platform selector: ' + key)
        if key in seen:
            continue
        seen.add(key)
        yield key, platforms[key]

def clone_sigs_if_needed():
    sigs_path = sigs_dir()
    if os.path.isdir(sigs_path):
        return
    sigs_url = args.sigs_url
    if not sigs_url:
        for env_var in DEFAULT_SIGS_ENV_VARS:
            sigs_url = os.environ.get(env_var)
            if sigs_url:
                break
    if not sigs_url:
        raise Exception(
            'Missing Gitian signatures repository. Pass --sigs-url or set '
            + ' / '.join(DEFAULT_SIGS_ENV_VARS)
            + '.'
        )
    subprocess.check_call(['git', 'clone', sigs_url, sigs_path])

def setup():
    global args, workdir
    programs = ['apt-cacher-ng', 'ruby', 'git', 'make', 'wget']
    if args.kvm:
        programs += ['python-vm-builder', 'qemu-kvm', 'qemu-utils']
    else:
        programs += ['lxc', 'debootstrap']
    if not args.no_apt:
        subprocess.check_call(['sudo', 'apt-get', 'install', '-qq'] + programs)
    clone_sigs_if_needed()
    if not os.path.isdir('builder'):
        subprocess.check_call(['git', 'clone', gbrepo, 'builder'])
    os.chdir('builder')
    subprocess.check_call(['git', 'checkout', 'c0f77ca018cb5332bfd595e0aff0468f77542c23'])
    os.makedirs('inputs', exist_ok=True)
    os.chdir('inputs')
    for source_dir in ('monero', PROJECT_SLUG):
        if os.path.isdir(source_dir):
            # Remove the potentially stale source dir. Otherwise you might face submodule mismatches.
            subprocess.check_call(['rm', source_dir, '-fR'])
    subprocess.check_call(['git', 'clone', args.url, PROJECT_SLUG])
    os.chdir('..')
    make_image_prog = ['bin/make-base-vm', '--suite', 'bionic', '--arch', 'amd64']
    if args.docker:
        try:
            subprocess.check_output(['docker', '--help'])
        except:
            print("ERROR: Could not find 'docker' command. Ensure this is in your PATH.")
            sys.exit(1)
        make_image_prog += ['--docker']
    elif not args.kvm:
        make_image_prog += ['--lxc']
    subprocess.check_call(make_image_prog)
    os.chdir(workdir)
    if args.is_bionic and not args.kvm and not args.docker:
        subprocess.check_call(['sudo', 'sed', '-i', 's/lxcbr0/br0/', '/etc/default/lxc-net'])
        print('Reboot is required')
        sys.exit(0)

def rebuild():
    global args, workdir

    print('\nBuilding Dependencies\n')
    os.makedirs('../out/' + args.version, exist_ok=True)


    for _, platform in selected_platforms():
        os_name = platform[0]
        tag_name = platform[1]
        suffix = platform[2]

        print('\nCompiling ' + args.version + ' ' + os_name)
        infile = 'inputs/' + PROJECT_SLUG + '/contrib/gitian/gitian-' + tag_name + '.yml'
        subprocess.check_call(['bin/gbuild', '-j', args.jobs, '-m', args.memory, '--commit', PROJECT_SLUG + '=' + args.commit, '--url', PROJECT_SLUG + '=' + args.url, infile])
        subprocess.check_call(['bin/gsign', '-p', args.sign_prog, '--signer', args.signer, '--release', args.version+'-'+tag_name, '--destination', sigs_dir(), infile])
        subprocess.check_call('mv build/out/' + PROJECT_SLUG + '-*.' + suffix + ' ../out/'+args.version, shell=True)
        print('Moving var/install.log to var/install-' + tag_name + '.log')
        subprocess.check_call('mv var/install.log var/install-' + tag_name + '.log', shell=True)
        print('Moving var/build.log to var/build-' + tag_name + '.log')
        subprocess.check_call('mv var/build.log var/build-' + tag_name + '.log', shell=True)

    os.chdir(workdir)

    if args.commit_files:
        print('\nCommitting '+args.version+' Unsigned Sigs\n')
        os.chdir(sigs_dir())
        for _, platform in selected_platforms():
            subprocess.check_call(['git', 'add', args.version+'-'+platform[1]+'/'+args.signer])
        subprocess.check_call(['git', 'commit', '-m', 'Add '+args.version+' unsigned sigs for '+args.signer])
        os.chdir(workdir)


def build():
    global args, workdir

    print('\nChecking Depends Freshness\n')
    os.chdir('builder')
    os.makedirs('inputs', exist_ok=True)

    subprocess.check_call(['make', '-C', 'inputs/' + PROJECT_SLUG + '/contrib/depends', 'download', 'SOURCES_PATH=' + os.getcwd() + '/cache/common'])

    rebuild()


def verify():
    global args, workdir
    os.chdir('builder')

    for _, platform in selected_platforms():
        print('\nVerifying ' + args.version + ' ' + platform[0] + '\n')
        subprocess.check_call(['bin/gverify', '-v', '-d', sigs_dir(), '-r', args.version+'-'+platform[1], 'inputs/' + PROJECT_SLUG + '/contrib/gitian/gitian-'+platform[1]+'.yml'])
    os.chdir(workdir)

def main():
    global args, workdir

    parser = argparse.ArgumentParser(description='Script for running full Gitian builds.', usage='%(prog)s [options] signer version')
    parser.add_argument('-c', '--commit', action='store_true', dest='commit', help='Indicate that the version argument is for a commit or branch')
    parser.add_argument('-p', '--pull', action='store_true', dest='pull', help='Indicate that the version argument is the number of a github repository pull request')
    parser.add_argument('-u', '--url', dest='url', default=DEFAULT_SOURCE_URL, help='Specify the URL of the repository. Default is %(default)s')
    parser.add_argument('-v', '--verify', action='store_true', dest='verify', help='Verify the Gitian build')
    parser.add_argument('-b', '--build', action='store_true', dest='build', help='Do a Gitian build')
    parser.add_argument('-B', '--buildsign', action='store_true', dest='buildsign', help='Build both signed and unsigned binaries')
    parser.add_argument('-o', '--os', dest='os', default='lafwm', help='Specify which Operating Systems the build is for. Default is %(default)s. l for Linux, a for Android, f for FreeBSD, w for Windows, m for MacOS')
    parser.add_argument('-r', '--rebuild', action='store_true', dest='rebuild', help='Redo a Gitian build')
    parser.add_argument('-R', '--rebuildsign', action='store_true', dest='rebuildsign', help='Redo and sign a Gitian build')
    parser.add_argument('-j', '--jobs', dest='jobs', default='2', help='Number of processes to use. Default %(default)s')
    parser.add_argument('-m', '--memory', dest='memory', default='2000', help='Memory to allocate in MiB. Default %(default)s')
    parser.add_argument('-k', '--kvm', action='store_true', dest='kvm', help='Use KVM instead of LXC')
    parser.add_argument('-d', '--docker', action='store_true', dest='docker', help='Use Docker instead of LXC')
    parser.add_argument('-S', '--setup', action='store_true', dest='setup', help='Set up the Gitian building environment. Uses LXC. If you want to use KVM, use the --kvm option. If you run this script on a non-debian based system, pass the --no-apt flag')
    parser.add_argument('-D', '--detach-sign', action='store_true', dest='detach_sign', help='Create the assert file for detached signing. Will not commit anything.')
    parser.add_argument('-n', '--no-commit', action='store_false', dest='commit_files', help='Do not commit anything to git')
    parser.add_argument('--sigs-dir', dest='sigs_dir', default='sigs', help='Directory for the Gitian signatures checkout. Default is %(default)s')
    parser.add_argument('--sigs-url', dest='sigs_url', default=None, help='Git URL for the Gitian signatures repository. Required when the signatures checkout is absent.')
    parser.add_argument('signer', nargs='?', help='GPG signer to sign each build assert file')
    parser.add_argument('version', nargs='?', help='Version number, commit, or branch to build.')
    parser.add_argument('-a', '--no-apt', action='store_true', dest='no_apt', help='Indicate that apt is not installed on the system')

    args = parser.parse_args()
    workdir = os.getcwd()

    args.is_bionic = b'bionic' in subprocess.check_output(['lsb_release', '-cs'])

    if args.buildsign:
        args.build = True
        args.sign = True

    if args.rebuildsign:
        args.rebuild = True
        args.sign = True

    if args.kvm and args.docker:
        raise Exception('Error: cannot have both kvm and docker')

    args.sign_prog = 'true' if args.detach_sign else 'gpg --detach-sign'

    # Set enviroment variable USE_LXC or USE_DOCKER, let gitian-builder know that we use lxc or docker
    if args.docker:
        os.environ['USE_DOCKER'] = '1'
    elif not args.kvm:
        os.environ['USE_LXC'] = '1'
        if not 'GITIAN_HOST_IP' in os.environ.keys():
            os.environ['GITIAN_HOST_IP'] = '10.0.2.2'
        if not 'LXC_GUEST_IP' in os.environ.keys():
            os.environ['LXC_GUEST_IP'] = '10.0.2.5'

    script_name = os.path.basename(sys.argv[0])
    # Signer and version shouldn't be empty
    if not args.signer:
        print(script_name+': Missing signer.')
        print('Try '+script_name+' --help for more information')
        sys.exit(1)
    if not args.version:
        print(script_name+': Missing version.')
        print('Try '+script_name+' --help for more information')
        sys.exit(1)

    # Add leading 'v' for tags
    if args.commit and args.pull:
        raise Exception('Cannot have both commit and pull')
    args.commit = args.commit if args.commit else args.version

    if args.setup:
        setup()

    source_checkout = os.path.join(workdir, 'builder', 'inputs', PROJECT_SLUG)
    legacy_source_checkout = os.path.join(workdir, 'builder', 'inputs', 'monero')
    if not os.path.isdir(os.path.join(source_checkout, '.git')):
        if os.path.isdir(os.path.join(legacy_source_checkout, '.git')):
            raise Exception(
                'Found a legacy builder/inputs/monero checkout. Re-run with --setup to refresh the builder inputs for '
                + PROJECT_NAME + '.'
            )
        raise Exception(
            'Missing builder/inputs/' + PROJECT_SLUG + ' checkout. Run --setup before building or verifying.'
        )

    os.chdir(source_checkout)
    if args.pull:
        subprocess.check_call(['git', 'fetch', args.url, 'refs/pull/'+args.version+'/merge'])
        args.commit = subprocess.check_output(['git', 'show', '-s', '--format=%H', 'FETCH_HEAD'], universal_newlines=True).strip()
        args.version = 'pull-' + args.version
    print(args.commit)
    subprocess.check_call(['git', 'fetch'])
    subprocess.check_call(['git', 'checkout', args.commit])
    os.chdir(workdir)

    if args.build:
        build()

    if args.rebuild:
        os.chdir('builder')
        rebuild()

    if args.verify:
        verify()

if __name__ == '__main__':
    main()
