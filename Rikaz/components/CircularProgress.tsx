import React from 'react';
import { View } from 'react-native';
import Svg, { Circle, Defs, Stop, LinearGradient as SvgLinearGradient } from 'react-native-svg';

type Props = {
  progress: number;        // 0..100
  size?: number;           // px
  strokeWidth?: number;    // px
  isBreakMode?: boolean;
};

export const CircularProgress: React.FC<Props> = ({
  progress,
  size = 240,
  strokeWidth = 8,
  isBreakMode = false,
}) => {
  const radius = (size - strokeWidth) / 2;
  const circumference = radius * 2 * Math.PI;
  const pct = Math.max(0, Math.min(100, progress)) / 100;
  const dashOffset = circumference - pct * circumference;
  const cx = size / 2;
  const cy = size / 2;

  return (
    <View style={{ width: size, height: size }}>
      <Svg width={size} height={size} style={{ transform: [{ rotate: '-90deg' }] }}>
        <Defs>
          <SvgLinearGradient id="gradFocus" x1="0" y1="0" x2="1" y2="1">
            <Stop offset="0" stopColor="#3b82f6" />
            <Stop offset="1" stopColor="#1d4ed8" />
          </SvgLinearGradient>
          <SvgLinearGradient id="gradBreak" x1="0" y1="0" x2="1" y2="1">
            <Stop offset="0" stopColor="#f59e0b" />
            <Stop offset="1" stopColor="#d97706" />
          </SvgLinearGradient>
        </Defs>

        {/* background ring */}
        <Circle cx={cx} cy={cy} r={radius} stroke="#EEF2F7" strokeWidth={strokeWidth} fill="transparent" />

        {/* progress ring */}
        <Circle
          cx={cx}
          cy={cy}
          r={radius}
          stroke={isBreakMode ? 'url(#gradBreak)' : 'url(#gradFocus)'}
          strokeWidth={strokeWidth}
          fill="transparent"
          strokeDasharray={circumference}
          strokeDashoffset={dashOffset}
          strokeLinecap="round"
        />
      </Svg>
    </View>
  );
};
