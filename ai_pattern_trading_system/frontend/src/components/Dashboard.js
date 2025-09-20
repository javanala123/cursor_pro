import React, { useState, useEffect } from 'react';
import { 
  Card, 
  Row, 
  Col, 
  Statistic, 
  Progress, 
  Alert, 
  Table, 
  Tag, 
  Badge,
  Timeline,
  Spin
} from 'antd';
import { 
  RobotOutlined, 
  LineChartOutlined, 
  DollarOutlined, 
  TrophyOutlined,
  TrendingUpOutlined,
  TrendingDownOutlined
} from '@ant-design/icons';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts';

const Dashboard = ({ systemStatus, realTimeData, isConnected }) => {
  const [loading, setLoading] = useState(false);

  // 실시간 차트 데이터 생성
  const generateChartData = () => {
    const data = [];
    const now = new Date();
    
    for (let i = 29; i >= 0; i--) {
      const time = new Date(now.getTime() - i * 60000); // 1분 간격
      data.push({
        time: time.toLocaleTimeString(),
        price: 50000 + Math.random() * 1000 - 500,
        volume: Math.random() * 1000,
        ai_signal: Math.random() > 0.7 ? (Math.random() > 0.5 ? 'buy' : 'sell') : null
      });
    }
    return data;
  };

  const chartData = generateChartData();

  // AI 분석 결과 표시
  const renderAIAnalysis = () => {
    if (!realTimeData.data) return null;

    const { data } = realTimeData;
    return (
      <Card title="🤖 AI 실시간 분석" size="small">
        <Row gutter={16}>
          <Col span={8}>
            <Statistic
              title="AI 신뢰도"
              value={data.reversal_confidence || 0}
              precision={2}
              suffix="%"
              valueStyle={{ 
                color: (data.reversal_confidence || 0) > 80 ? '#3f8600' : '#cf1322' 
              }}
            />
          </Col>
          <Col span={8}>
            <Statistic
              title="패턴 유사도"
              value={data.pattern_similarity || 0}
              precision={2}
              suffix="%"
              valueStyle={{ 
                color: (data.pattern_similarity || 0) > 90 ? '#3f8600' : '#cf1322' 
              }}
            />
          </Col>
          <Col span={8}>
            <Statistic
              title="예상 수익"
              value={data.expected_profit || 0}
              precision={2}
              suffix=" pips"
              valueStyle={{ 
                color: (data.expected_profit || 0) > 0 ? '#3f8600' : '#cf1322' 
              }}
            />
          </Col>
        </Row>
        
        <div style={{ marginTop: '16px' }}>
          <Tag color={data.should_trade ? 'green' : 'default'}>
            {data.should_trade ? '거래 신호 감지' : '대기 중'}
          </Tag>
          <Tag color={data.trade_direction === 'buy' ? 'blue' : data.trade_direction === 'sell' ? 'red' : 'default'}>
            {data.trade_direction === 'buy' ? '매수' : data.trade_direction === 'sell' ? '매도' : '대기'}
          </Tag>
        </div>
      </Card>
    );
  };

  // 거래 통계
  const tradingStats = [
    {
      title: '총 거래 수',
      value: systemStatus.total_trades || 0,
      icon: <LineChartOutlined />,
      color: '#1890ff'
    },
    {
      title: '승률',
      value: systemStatus.win_rate || 0,
      suffix: '%',
      icon: <TrophyOutlined />,
      color: '#52c41a'
    },
    {
      title: '총 수익',
      value: systemStatus.total_profit || 0,
      prefix: '$',
      icon: <DollarOutlined />,
      color: systemStatus.total_profit > 0 ? '#52c41a' : '#ff4d4f'
    },
    {
      title: '활성 포지션',
      value: systemStatus.active_positions || 0,
      icon: <RobotOutlined />,
      color: '#722ed1'
    }
  ];

  // 최근 거래 이력
  const recentTrades = systemStatus.positions || [];
  const tradeColumns = [
    {
      title: '심볼',
      dataIndex: 'symbol',
      key: 'symbol',
    },
    {
      title: '방향',
      dataIndex: 'side',
      key: 'side',
      render: (side) => (
        <Tag color={side === 'buy' ? 'blue' : 'red'}>
          {side === 'buy' ? '매수' : '매도'}
        </Tag>
      ),
    },
    {
      title: '수량',
      dataIndex: 'amount',
      key: 'amount',
      render: (amount) => amount?.toFixed(4)
    },
    {
      title: '진입가',
      dataIndex: 'entry_price',
      key: 'entry_price',
      render: (price) => `$${price?.toFixed(2)}`
    },
    {
      title: '현재가',
      dataIndex: 'current_price',
      key: 'current_price',
      render: (price) => `$${price?.toFixed(2)}`
    },
    {
      title: '미실현 손익',
      dataIndex: 'unrealized_pnl',
      key: 'unrealized_pnl',
      render: (pnl) => (
        <span style={{ color: pnl > 0 ? '#52c41a' : '#ff4d4f' }}>
          ${pnl?.toFixed(2)}
        </span>
      ),
    },
  ];

  return (
    <div>
      {/* 연결 상태 알림 */}
      {!isConnected && (
        <Alert
          message="서버 연결 끊어짐"
          description="AI 시스템과의 연결이 끊어졌습니다. 잠시 후 다시 시도해주세요."
          type="error"
          showIcon
          style={{ marginBottom: '20px' }}
        />
      )}

      {/* AI 분석 결과 */}
      {renderAIAnalysis()}

      {/* 거래 통계 */}
      <Row gutter={16} style={{ marginTop: '20px' }}>
        {tradingStats.map((stat, index) => (
          <Col span={6} key={index}>
            <Card>
              <Statistic
                title={stat.title}
                value={stat.value}
                prefix={stat.prefix}
                suffix={stat.suffix}
                valueStyle={{ color: stat.color }}
                prefix={stat.icon}
              />
            </Card>
          </Col>
        ))}
      </Row>

      {/* 실시간 차트 */}
      <Row gutter={16} style={{ marginTop: '20px' }}>
        <Col span={16}>
          <Card title="📈 실시간 가격 차트" size="small">
            <ResponsiveContainer width="100%" height={300}>
              <LineChart data={chartData}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="time" />
                <YAxis />
                <Tooltip />
                <Line 
                  type="monotone" 
                  dataKey="price" 
                  stroke="#1890ff" 
                  strokeWidth={2}
                  dot={false}
                />
              </LineChart>
            </ResponsiveContainer>
          </Card>
        </Col>
        
        <Col span={8}>
          <Card title="🎯 AI 신호" size="small">
            <Timeline>
              {chartData
                .filter(item => item.ai_signal)
                .slice(-5)
                .map((item, index) => (
                  <Timeline.Item
                    key={index}
                    color={item.ai_signal === 'buy' ? 'green' : 'red'}
                  >
                    <div style={{ fontSize: '12px' }}>
                      <div>{item.time}</div>
                      <Tag color={item.ai_signal === 'buy' ? 'green' : 'red'}>
                        {item.ai_signal === 'buy' ? '매수' : '매도'}
                      </Tag>
                    </div>
                  </Timeline.Item>
                ))}
            </Timeline>
          </Card>
        </Col>
      </Row>

      {/* 활성 포지션 */}
      <Card title="💼 활성 포지션" style={{ marginTop: '20px' }}>
        <Table
          columns={tradeColumns}
          dataSource={recentTrades}
          pagination={false}
          size="small"
          rowKey="symbol"
        />
      </Card>

      {/* 시스템 상태 */}
      <Card title="⚙️ 시스템 상태" style={{ marginTop: '20px' }}>
        <Row gutter={16}>
          <Col span={8}>
            <div style={{ textAlign: 'center' }}>
              <div style={{ fontSize: '24px', marginBottom: '8px' }}>
                {systemStatus.is_auto_trading ? '🟢' : '🔴'}
              </div>
              <div>자동 거래</div>
              <div style={{ fontSize: '12px', color: '#666' }}>
                {systemStatus.is_auto_trading ? '활성화' : '비활성화'}
              </div>
            </div>
          </Col>
          <Col span={8}>
            <div style={{ textAlign: 'center' }}>
              <div style={{ fontSize: '24px', marginBottom: '8px' }}>
                📊
              </div>
              <div>일일 거래</div>
              <div style={{ fontSize: '12px', color: '#666' }}>
                {systemStatus.daily_trade_count || 0} / {systemStatus.max_daily_trades || 10}
              </div>
            </div>
          </Col>
          <Col span={8}>
            <div style={{ textAlign: 'center' }}>
              <div style={{ fontSize: '24px', marginBottom: '8px' }}>
                🤖
              </div>
              <div>AI 분석</div>
              <div style={{ fontSize: '12px', color: '#666' }}>
                실시간 모니터링
              </div>
            </div>
          </Col>
        </Row>
      </Card>
    </div>
  );
};

export default Dashboard;
