'use strict';
'use __view__';

return L.view.extend({
    // Mematikan pengambilan data default LuCI
    load: function() {
        return Promise.resolve();
    },

    render: function() {
        // Container dibuat setinggi layar (100vh) dan mematikan scroll luar
        return E('div', { 
            'style': 'margin: -15px; background: #020b14; height: 100vh; overflow: hidden;' 
        }, [
            E('iframe', {
                'src': '/luci-static/custom/monitor.html',
                'style': 'width: 100%; height: 100%; border: none; display: block;',
                'scrolling': 'yes', // Mengizinkan scroll hanya di dalam dashboard monitor
                'id': 'custom_monitor_frame'
            })
        ]);
    },

    // Mematikan fungsi save/reset bawaan agar tidak muncul tombol di bawah
    handleSave: null,
    handleSaveApply: null,
    handleReset: null
});
