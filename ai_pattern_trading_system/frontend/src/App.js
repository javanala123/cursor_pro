import React, { useState, useEffect } from 'react';
import { Layout, Menu, Card, Row, Col, Statistic, Alert, Spin } from 'antd';
import { 
  DashboardOutlined, 
  LineChartOutlined, 
  SettingOutlined, 
  RobotOutlined,
  BarChartOutlined,
  HistoryOutlined
} from '@ant-design/icons';
import io from 'socket.io-client';
import axios from 'axios';

// 컴포넌트들
import Dashboard from './components/Dashboard';
import PatternAnalysis from './components/PatternAnalysis';
import TradingPanel from './components/TradingPanel';
import Settings from './components/Settings';
import Performance from './components/Performance';
import TradeHistory from './components/TradeHistory';

// WebSocket 연결
const socket = io('http://localhost:8000');

const { Header, Sider, Content } = Layout;

function App() {
  const [selectedMenu, setSelectedMenu] = useState('dashboard');
  const [isConnected, setIsConnected] = useState(false);
  const [loading, setLoading] = useState(true);
  const [systemStatus, setSystemStatus] = useState({});
  const [realTimeData, setRealTimeData] = useState({});

  // WebSocket 연결 관리
  useEffect(() => {
    socket.on('connect', () => {
      console.log('✅ WebSocket 연결됨');
      setIsConnected(true);
      setLoading(false);
    });

    socket.on('disconnect', () => {
      console.log('❌ WebSocket 연결 끊어짐');
      setIsConnected(false);
    });

    socket.on('analysis_result', (data) => {
      console.log('🔍 AI 분석 결과:', data);
      setRealTimeData(data);
    });

    socket.on('pattern_info', (data) => {
      console.log('📊 패턴 정보:', data);
      setSystemStatus(prev => ({ ...prev, patterns: data }));
    });

    return () => {
      socket.disconnect();
    };
  }, []);

  // 시스템 상태 조회
  useEffect(() => {
    const fetchSystemStatus = async () => {
      try {
        const response = await axios.get('http://localhost:8000/api/trading/status');
        setSystemStatus(response.data);
      } catch (error) {
        console.error('시스템 상태 조회 오류:', error);
      }
    };

    fetchSystemStatus();
    const interval = setInterval(fetchSystemStatus, 5000); // 5초마다 업데이트

    return () => clearInterval(interval);
  }, []);

  const menuItems = [
    {
      key: 'dashboard',
      icon: <DashboardOutlined />,
      label: '대시보드',
    },
    {
      key: 'patterns',
      icon: <LineChartOutlined />,
      label: '패턴 분석',
    },
    {
      key: 'trading',
      icon: <RobotOutlined />,
      label: 'AI 거래',
    },
    {
      key: 'performance',
      icon: <BarChartOutlined />,
      label: '성과 분석',
    },
    {
      key: 'history',
      icon: <HistoryOutlined />,
      label: '거래 이력',
    },
    {
      key: 'settings',
      icon: <SettingOutlined />,
      label: '설정',
    },
  ];

  const renderContent = () => {
    switch (selectedMenu) {
      case 'dashboard':
        return <Dashboard 
          systemStatus={systemStatus} 
          realTimeData={realTimeData}
          isConnected={isConnected}
        />;
      case 'patterns':
        return <PatternAnalysis realTimeData={realTimeData} />;
      case 'trading':
        return <TradingPanel 
          systemStatus={systemStatus}
          realTimeData={realTimeData}
          socket={socket}
        />;
      case 'performance':
        return <Performance systemStatus={systemStatus} />;
      case 'history':
        return <TradeHistory systemStatus={systemStatus} />;
      case 'settings':
        return <Settings />;
      default:
        return <Dashboard 
          systemStatus={systemStatus} 
          realTimeData={realTimeData}
          isConnected={isConnected}
        />;
    }
  };

  if (loading) {
    return (
      <div style={{ 
        display: 'flex', 
        justifyContent: 'center', 
        alignItems: 'center', 
        height: '100vh' 
      }}>
        <Spin size="large" tip="AI 시스템 초기화 중..." />
      </div>
    );
  }

  return (
    <Layout style={{ minHeight: '100vh' }}>
      <Sider width={250} theme="dark">
        <div style={{ 
          padding: '20px', 
          textAlign: 'center', 
          borderBottom: '1px solid #303030' 
        }}>
          <RobotOutlined style={{ fontSize: '24px', color: '#1890ff' }} />
          <h3 style={{ color: 'white', margin: '10px 0 0 0' }}>
            AI Pattern Trading
          </h3>
        </div>
        
        <Menu
          theme="dark"
          mode="inline"
          selectedKeys={[selectedMenu]}
          items={menuItems}
          onClick={({ key }) => setSelectedMenu(key)}
        />
      </Sider>

      <Layout>
        <Header style={{ 
          background: '#fff', 
          padding: '0 20px',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          borderBottom: '1px solid #f0f0f0'
        }}>
          <h2 style={{ margin: 0 }}>
            {menuItems.find(item => item.key === selectedMenu)?.label}
          </h2>
          
          <div style={{ display: 'flex', alignItems: 'center', gap: '20px' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
              <div style={{
                width: '8px',
                height: '8px',
                borderRadius: '50%',
                backgroundColor: isConnected ? '#52c41a' : '#ff4d4f'
              }} />
              <span>{isConnected ? '연결됨' : '연결 끊어짐'}</span>
            </div>
            
            {systemStatus.is_auto_trading && (
              <Alert
                message="AI 자동 거래 활성화"
                type="success"
                showIcon
                style={{ margin: 0 }}
              />
            )}
          </div>
        </Header>

        <Content style={{ padding: '20px', background: '#f5f5f5' }}>
          {renderContent()}
        </Content>
      </Layout>
    </Layout>
  );
}

export default App;
