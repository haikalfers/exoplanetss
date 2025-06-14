const express = require('express');
const bodyParser = require('body-parser');
const fs = require('fs').promises;
const path = require('path');
const cors = require('cors');
const app = express();
const PORT = 3000;

// Middleware
app.use(bodyParser.json());
app.use(cors()); // Aktifkan CORS untuk Flutter app

// Data planet lokal (backup)
let planetData = [];

// Inisialisasi data dari file lokal
async function loadLocalData() {
  try {
    const data = await fs.readFile(path.join(__dirname, 'planets-data.json'), 'utf8');
    planetData = JSON.parse(data);
    console.log('Data planet lokal berhasil dimuat');
  } catch (error) {
    console.error('Error loading local data:', error);
    planetData = []; // Data default kosong
  }
}

// ✅ Tambahan GET '/' agar tidak error saat buka di browser
app.get('/', (req, res) => {
  res.send('🌍 JSON-RPC Server for Exoplanets is running!');
});

// Metode-metode JSON-RPC
const methods = {
  getAllPlanets: async () => {
    return planetData;
  },
  getPlanetByName: async (name) => {
    return planetData.filter(planet => planet.pl_name === name);
  },
  getPlanetsByDiscYear: async (year) => {
    return planetData.filter(planet => planet.disc_year === year);
  },
  getPlanetsByHostname: async (hostname) => {
    return planetData.filter(planet => planet.hostname === hostname);
  }
};

// Endpoint JSON-RPC
app.post('/rpc', async (req, res) => {
  const rpcRequest = req.body;

  if (!rpcRequest.jsonrpc || rpcRequest.jsonrpc !== '2.0' || !rpcRequest.method) {
    return res.json({
      jsonrpc: '2.0',
      error: { code: -32600, message: 'Invalid Request' },
      id: rpcRequest.id || null
    });
  }

  const method = methods[rpcRequest.method];
  if (!method) {
    return res.json({
      jsonrpc: '2.0',
      error: { code: -32601, message: 'Method not found' },
      id: rpcRequest.id
    });
  }

  try {
    const result = await method(...(rpcRequest.params || []));
    res.json({
      jsonrpc: '2.0',
      result: result,
      id: rpcRequest.id
    });
  } catch (error) {
    res.json({
      jsonrpc: '2.0',
      error: {
        code: error.code || -32603,
        message: error.message || 'Internal error'
      },
      id: rpcRequest.id
    });
  }
});

// Endpoint opsional untuk update data lokal
app.post('/update-local-data', async (req, res) => {
  try {
    await fs.writeFile(
      path.join(__dirname, 'planets-data.json'),
      JSON.stringify(req.body, null, 2)
    );

    planetData = req.body;

    res.json({ success: true, message: 'Data berhasil diperbarui' });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Gagal memperbarui data',
      error: error.message
    });
  }
});

// Inisialisasi aplikasi
async function init() {
  await loadLocalData();
  app.listen(PORT, () => {
    console.log(`✅ JSON-RPC server berjalan di http://localhost:${PORT}`);
  });
}

init();
