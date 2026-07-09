import GObject from 'gi://GObject';
import Gio from 'gi://Gio';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import {QuickToggle, SystemIndicator} from 'resource:///org/gnome/shell/ui/quickSettings.js';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

const HELPER = '/usr/local/libexec/gnome-vpn-killswitch/toggle';

function runHelper(args, onDone) {
    try {
        const proc = Gio.Subprocess.new(
            ['pkexec', HELPER, ...args],
            Gio.SubprocessFlags.STDOUT_PIPE
        );
        proc.communicate_utf8_async(null, null, (p, res) => {
            try {
                const [, stdout] = p.communicate_utf8_finish(res);
                onDone(p.get_exit_status() === 0, stdout.trim());
            } catch (e) {
                logError(e);
                onDone(false, '');
            }
        });
    } catch (e) {
        logError(e);
        onDone(false, '');
    }
}

const KillSwitchToggle = GObject.registerClass(
class KillSwitchToggle extends QuickToggle {
    _init() {
        super._init({
            title: 'Kill Switch',
            iconName: 'network-vpn-symbolic',
            toggleMode: true,
        });
        this._syncing = false;
        this._syncFromBackend();
        this.connect('clicked', () => this._onClicked());
    }

    _syncFromBackend() {
        runHelper(['status'], (ok, stdout) => {
            this._syncing = true;
            this.checked = ok && stdout === 'on';
            this._syncing = false;
        });
    }

    _onClicked() {
        if (this._syncing)
            return;
        const wanted = this.checked;
        runHelper([wanted ? 'on' : 'off'], ok => {
            if (!ok) {
                this._syncing = true;
                this.checked = !wanted;
                this._syncing = false;
            }
        });
    }
});

const Indicator = GObject.registerClass(
class Indicator extends SystemIndicator {
    _init() {
        super._init();
        this.quickSettingsItems.push(new KillSwitchToggle());
    }
});

export default class GnomeVpnKillswitchExtension extends Extension {
    enable() {
        this._indicator = new Indicator();
        Main.panel.statusArea.quickSettings.addExternalIndicator(this._indicator);
    }

    disable() {
        this._indicator.quickSettingsItems.forEach(item => item.destroy());
        this._indicator.destroy();
        this._indicator = null;
    }
}
