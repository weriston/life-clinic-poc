import React, { useState, useEffect } from 'react';
import { FaHome, FaCalendarAlt, FaHandHoldingUsd, FaHeart } from 'react-icons/fa';
import DatePicker from 'react-datepicker';
import 'react-datepicker/dist/react-datepicker.css';
import { MapContainer, TileLayer, Marker, Popup } from 'react-leaflet';
import 'leaflet/dist/leaflet.css';

function App() {
  // Hooks no top
  const [view, setView] = useState('home');
  const [data, setData] = useState({ idade: '', localizacao: '', especialidade: '' });
  const [recomendacao, setRecomendacao] = useState(null);
  const [selectedSpecialist, setSelectedSpecialist] = useState(null);
  const [selectedDate, setSelectedDate] = useState(new Date());
  const [insumos, setInsumos] = useState([]);

  useEffect(() => {
    if (view === 'insumos') {
      fetch('http://localhost:3001/api/insumos')
        .then(res => res.json())
        .then(result => setInsumos(result.insumos || []))
        .catch(() => setInsumos([]));
    }
  }, [view]);

  // Handlers
  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      const response = await fetch('http://localhost:3001/api/recomendar', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data)
      });
      const result = await response.json();
      if (result.error) {
        setRecomendacao('Erro na recomendação. Verifique backend.');
        return;
      }
      setRecomendacao(result.recomendacao);  // String full para card
      setSelectedSpecialist({
        name: result.nome,
        specialty: result.especialidade,
        location: result.localizacao,
        city: result.cidade,
        similarity: result.similaridade,
        lat: result.lat,
        lng: result.lng,
        bio: result.bio
      });
      // Fica em matching para ver lovable card
    } catch (error) {
      setRecomendacao('Erro de conexão: Backend em localhost:3001?');
    }
  };

  const handleAgendar = () => {
    setView('agendar');
  };

  const handleConfirmar = async () => {
    try {
      const response = await fetch('http://localhost:3001/api/agendar', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          data: selectedDate.toLocaleDateString('pt-BR'),
          hora: selectedDate.toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' }),
          especialista: selectedSpecialist ? selectedSpecialist.name : 'Especialista'
        })
      });
      const result = await response.json();
      if (result.success) {
        alert(`Agendado! ID: ${result.agendamento.id}\nData: ${result.agendamento.data} às ${result.agendamento.hora}`);
        setView('home');
      } else {
        alert('Erro no agendamento.');
      }
    } catch (error) {
      alert(`Erro: ${error.message}. Backend rodando?`);
    }
  };

  // View Home (com <style> keyframes para animações lovable)
  if (view === 'home') {
    return (
      <div style={{ padding: '20px', fontFamily: 'Arial, sans-serif', maxWidth: '500px', margin: '0 auto', background: '#F5F6F8' }}>
        {/* Keyframes CSS para animações (inline, sem arquivo extra) */}
        <style>{`
          @keyframes fadeIn {
            from { opacity: 0; transform: translateY(10px); }
            to { opacity: 1; transform: translateY(0); }
          }
          @keyframes spin {
            from { transform: rotate(0deg); }
            to { transform: rotate(360deg); }
          }
          @keyframes pulse {
            0%, 100% { transform: scale(1); }
            50% { transform: scale(1.05); }
          }
          .lovable-anim { animation: fadeIn 0.5s ease-out; }
          .spin { animation: spin 1.5s linear infinite; }
          .pulse { animation: pulse 2s infinite; }
        `}</style>
        <div style={{ textAlign: 'center', margin: '20px 0' }}>
          <img src="/logo-life-clinic.svg" alt="Life Clinic Logo" style={{ width: '120px', height: 'auto', display: 'block', margin: '0 auto' }} />
        </div>
        <p style={{ textAlign: 'center', color: '#666' }}>Rede de Acolhimento Inteligente para Infertilidade</p>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '20px', marginTop: '40px' }}>
          <div onClick={() => setView('matching')} style={{ textAlign: 'center', cursor: 'pointer', padding: '10px', border: '1px solid #ddd', borderRadius: '8px' }}>
            <FaHome size={40} color="#007bff" />
            <p>Rede de Acolhimento</p>
          </div>
          <div onClick={() => setView('agendar')} style={{ textAlign: 'center', cursor: 'pointer', padding: '10px', border: '1px solid #ddd', borderRadius: '8px' }}>
            <FaCalendarAlt size={40} color="#FF9800" />
            <p>Agendamento Online</p>
          </div>
          <div onClick={() => setView('insumos')} style={{ textAlign: 'center', cursor: 'pointer', padding: '10px', border: '1px solid #ddd', borderRadius: '8px' }}>
            <FaHandHoldingUsd size={40} color="#4CAF50" />
            <p>Smart Insumos</p>
          </div>
        </div>
        <p style={{ fontSize: '12px', color: '#999', textAlign: 'center', marginTop: '20px' }}>LGPD Compliant - Dados Mock</p>
      </div>
    );
  }

  // View Matching (com lovable card e comments em {})
  if (view === 'matching') {
    return (
      <div style={{ padding: '20px', fontFamily: 'Arial, sans-serif', maxWidth: '500px', margin: '0 auto' }}>
        <h2 style={{ color: '#007bff' }}>Matching IA</h2>
        <form onSubmit={handleSubmit}>
          <div style={{ marginBottom: '10px' }}>
            <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>Idade:</label>
            <input type="number" value={data.idade} onChange={(e) => setData({ ...data, idade: e.target.value })} required style={{ width: '100%', padding: '8px', border: '1px solid #ccc', borderRadius: '4px' }} />
          </div>
          <div style={{ marginBottom: '10px' }}>
            <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>Localização:</label>
            <input value={data.localizacao} onChange={(e) => setData({ ...data, localizacao: e.target.value })} required style={{ width: '100%', padding: '8px', border: '1px solid #ccc', borderRadius: '4px' }} />
          </div>
          <div style={{ marginBottom: '10px' }}>
            <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>Especialidade:</label>
            <input value={data.especialidade} onChange={(e) => setData({ ...data, especialidade: e.target.value })} required style={{ width: '100%', padding: '8px', border: '1px solid #ccc', borderRadius: '4px' }} />
          </div>
          <button type="submit" style={{ width: '100%', padding: '10px', background: '#007bff', color: 'white', border: 'none', borderRadius: '4px', cursor: 'pointer' }}>Recomendar</button>
        </form>
        {/* Lovable card com animações e comments em {} */}
        {recomendacao ? (
          <div className="lovable-anim" style={{ marginTop: '20px' }}>
            <div style={{ 
              padding: '20px', 
              background: 'linear-gradient(135deg, #d1ecf1 0%, #bee5eb 100%)', 
              borderRadius: '12px', 
              textAlign: 'center', 
              boxShadow: '0 4px 12px rgba(0,123,255,0.1)' 
            }}>
              <FaHeart className="pulse" size={40} color="#FF9800" style={{ marginBottom: '15px' }} />
              <h3 style={{ color: '#007bff', marginBottom: '10px', fontSize: '1.2em' }}>Esperança à Vista!</h3>
              <p style={{ color: '#0c5460', marginBottom: '10px', fontSize: '1em' }}>
                Você não está sozinho nessa jornada. {selectedSpecialist ? selectedSpecialist.name : 'um especialista'} é acolhedor que pode ajudar sua família a crescer em {selectedSpecialist ? selectedSpecialist.city : ''}.
              </p>
              <p style={{ color: '#666', marginBottom: '15px' }}>Especialidade: {selectedSpecialist ? selectedSpecialist.specialty : 'Recomendada'}</p>
              <p style={{ fontSize: '14px', color: '#666', marginBottom: '10px' }}>
                Similaridade: <span style={{ fontWeight: 'bold', color: '#4CAF50' }}>{Math.round(selectedSpecialist ? selectedSpecialist.similarity * 100 : 0)}%</span>
              </p>
              {/* Progress bar animada */}
              <div style={{ 
                width: '100%', height: '12px', background: '#e0e0e0', borderRadius: '6px', overflow: 'hidden', marginBottom: '10px' 
              }}>
                <div style={{ 
                  width: `${Math.round(selectedSpecialist ? selectedSpecialist.similarity * 100 : 0)}%`, 
                  height: '100%', background: 'linear-gradient(90deg, #4CAF50 0%, #8BC34A 100%)', 
                  transition: 'width 0.8s ease-in-out', borderRadius: '6px' 
                }}></div>
              </div>
              <button onClick={() => setView('profile')} style={{ 
                padding: '10px 20px', background: '#007bff', color: 'white', border: 'none', borderRadius: '6px', cursor: 'pointer', marginTop: '10px' 
              }}>
                Ver Perfil Completo
              </button>
            </div>
          </div>
        ) : (
          <div className="lovable-anim" style={{ textAlign: 'center', marginTop: '20px', padding: '20px', background: '#f8f9fa', borderRadius: '8px', opacity: 0.7 }}>
            <p style={{ color: '#666', fontSize: '16px' }}>Conectando você à nossa rede de acolhimento... <span className="spin">🌟</span></p>
            <p style={{ color: '#999', fontSize: '14px', marginTop: '5px' }}>Estamos calculando a melhor jornada para você com carinho e precisão.</p>
          </div>
        )}
        <button onClick={() => setView('home')} style={{ marginTop: '10px', width: '100%', padding: '10px', background: '#ccc', border: 'none', borderRadius: '4px', cursor: 'pointer' }}>Voltar Home</button>
      </div>
    );
  }

  // View Profile
  if (view === 'profile' && selectedSpecialist) {
    return (
      <div style={{ padding: '20px', fontFamily: 'Arial, sans-serif', maxWidth: '500px', margin: '0 auto' }}>
        <h2>Perfil Recomendado</h2>
        <div style={{ border: '1px solid #ddd', borderRadius: '8px', padding: '15px', marginBottom: '20px' }}>
          <h3>{selectedSpecialist.name} - {selectedSpecialist.city}</h3>
          <p>{selectedSpecialist.bio}</p>
          <p><strong>Similaridade:</strong> {Math.round(selectedSpecialist.similarity * 100)}%</p>
          <button onClick={handleAgendar} style={{ background: '#4CAF50', color: 'white', padding: '10px', border: 'none', borderRadius: '4px', marginRight: '10px' }}>Agendar</button>
          <button onClick={() => setView('home')} style={{ background: '#ccc', padding: '10px', border: 'none', borderRadius: '4px' }}>Voltar Home</button>
        </div>
        <h4>Mapa da Clínica</h4>
        <MapContainer center={[selectedSpecialist.lat, selectedSpecialist.lng]} zoom={12} style={{ height: '300px', width: '100%' }}>
          <TileLayer url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png" />
          <Marker position={[selectedSpecialist.lat, selectedSpecialist.lng]}>
            <Popup>Clínica {selectedSpecialist.name} - {selectedSpecialist.city}</Popup>
          </Marker>
        </MapContainer>
      </div>
    );
  }

  // View Agendar
  if (view === 'agendar') {
    return (
      <div style={{ padding: '20px', fontFamily: 'Arial, sans-serif', maxWidth: '500px', margin: '0 auto' }}>
        <h2 style={{ color: '#FF9800', textAlign: 'center' }}>Agendamento Online</h2>
        <p style={{ textAlign: 'center', color: '#666', marginBottom: '20px' }}>Selecione data e hora (mock {selectedSpecialist ? selectedSpecialist.name : 'especialista'} em {selectedSpecialist ? selectedSpecialist.city : ''}).</p>
        <DatePicker 
          selected={selectedDate} 
          onChange={setSelectedDate} 
          showTimeSelect 
          dateFormat="Pp" 
          inline 
          minDate={new Date()} 
          timeIntervals={30} 
          style={{ width: '100%', marginBottom: '20px' }} 
        />
        <button onClick={handleConfirmar} style={{ width: '100%', padding: '12px', background: '#FF9800', color: 'white', border: 'none', borderRadius: '4px', cursor: 'pointer', fontSize: '16px', marginBottom: '10px' }}>
          Confirmar Slot
        </button>
        <button onClick={() => setView('home')} style={{ width: '100%', padding: '12px', background: '#ccc', border: 'none', borderRadius: '4px', cursor: 'pointer' }}>
          Voltar Home
        </button>
      </div>
    );
  }

  // View Insumos
  if (view === 'insumos') {
    return (
      <div style={{ padding: '20px', fontFamily: 'Arial, sans-serif', maxWidth: '500px', margin: '0 auto' }}>
        <h2 style={{ color: '#4CAF50', textAlign: 'center' }}>Smart Insumos</h2>
        <p style={{ textAlign: 'center', color: '#666', marginBottom: '20px' }}>Gestão de estoque com alertas IA (mock).</p>
        <table style={{ width: '100%', borderCollapse: 'collapse', marginBottom: '20px' }}>
          <thead>
            <tr style={{ background: '#4CAF50', color: 'white' }}>
              <th style={{ padding: '8px', border: '1px solid #ddd' }}>Item</th>
              <th style={{ padding: '8px', border: '1px solid #ddd' }}>Quantidade</th>
              <th style={{ padding: '8px', border: '1px solid #ddd' }}>Alerta IA</th>
            </tr>
          </thead>
          <tbody>
            {insumos.map((item, idx) => (
              <tr key={idx}>
                <td style={{ padding: '8px', border: '1px solid #ddd' }}>{item.item}</td>
                <td style={{ padding: '8px', border: '1px solid #ddd' }}>{item.quantidade}</td>
                <td style={{ padding: '8px', border: '1px solid #ddd', color: item.alerta.includes('Baixo') ? 'red' : 'green' }}>{item.alerta}</td>
              </tr>
            ))}
          </tbody>
        </table>
        <button onClick={() => setView('home')} style={{ width: '100%', padding: '12px', background: '#ccc', border: 'none', borderRadius: '4px', cursor: 'pointer' }}>
          Voltar Home
        </button>
      </div>
    );
  }

  // Fallback com animação (sem unused var)
  return (
    <div className="lovable-anim" style={{ opacity: 0.5, textAlign: 'center', padding: '20px' }}>
      Carregando sua jornada...
    </div>
  );
}

export default App;