import { useRouter } from 'expo-router';
import React from 'react';
import {
  SafeAreaView,
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  StatusBar,
  Alert,
} from 'react-native';
import { Svg, Path, Text as SvgText } from 'react-native-svg';

// --- SVG Icons ---
// Using react-native-svg components as they are suitable for React Native environment

const PuzzleIcon: React.FC<{ color?: string }> = ({ color = '#A0A0A0' }) => (
  <Svg height="40" width="40" viewBox="0 0 24 24">
    <Path
      fill={color}
      d="M20.49 8.23c-1.42-2.1-4.2-2.78-6.49-1.92V3c0-.55-.45-1-1-1h-2c-.55 0-1 .45-1 1v3.31C8.21 5.45 5.43 6.13 4 8.23c-1.81 2.68-1.13 6.23 1.51 8.04C3.81 17.6 3 19.68 3 22h9.5c.28 0 .5-.22.5-.5V19c0-1.1.9-2 2-2s2 .9 2 2v2.5c0 .28.22.5.5.5H21c0-2.32-.81-4.4-2.49-5.73 2.64-1.81 3.32-5.36 1.98-8.04zM6.5 14c-1.93 0-3.5-1.57-3.5-3.5S4.57 7 6.5 7s3.5 1.57 3.5 3.5S8.43 14 6.5 14zm11 0c-1.93 0-3.5-1.57-3.5-3.5S15.57 7 17.5 7s3.5 1.57 3.5 3.5S19.43 14 17.5 14z"
    />
  </Svg>
);

const RiddleIcon = () => (
    <Svg height="32" width="32" viewBox="0 0 24 24">
        <Path fill="#8A8A8A" d="M12 2A7 7 0 0 0 5 9c0 2.38 1.19 4.47 3 5.74V17a1 1 0 0 0 1 1h6a1 1 0 0 0 1-1v-2.26c1.81-1.27 3-3.36 3-5.74A7 7 0 0 0 12 2zm1 16h-2v-1h2v1zm0-2h-2v-2h2v2z"/>
    </Svg>
);

const MathIcon = () => (
    <Svg height="32" width="32" viewBox="0 0 24 24">
        <Path fill="#8A8A8A" d="M19 3H5c-1.11 0-2 .9-2 2v14c0 1.1.89 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zM9.62 16.5H7.5V15h2.12c.66 0 1.13-.53 1.13-1.19c0-.66-.47-1.19-1.13-1.19H7.5V11h2.12c.66 0 1.13-.53 1.13-1.19c0-.66-.47-1.19-1.13-1.19H7.5V7.5h2.12c1.47 0 2.63 1.25 2.63 2.81c0 1.14-.68 2.13-1.68 2.56c1 .43 1.68 1.42 1.68 2.56c0 1.56-1.16 2.87-2.63 2.87zm7.38-6.35l-1.75 1.75l-1.75-1.75L12.15 11.5l1.75 1.75l-1.75 1.75l1.35 1.35l1.75-1.75l1.75 1.75l1.35-1.35l-1.75-1.75l1.75-1.75l-1.35-1.35z"/>
    </Svg>
);

const ClockIcon = () => (
    <Svg height="16" width="16" viewBox="0 0 24 24">
        <Path fill="#8A8A8A" d="M12 2C6.486 2 2 6.486 2 12s4.486 10 10 10s10-4.486 10-10S17.514 2 12 2zm0 18c-4.411 0-8-3.589-8-8s3.589-8 8-8s8 3.589 8 8s-3.589 8-8 8z"/>
        <Path fill="#8A8A8A" d="M13 7h-2v6h6v-2h-4V7z"/>
    </Svg>
);

const ListIcon = () => (
    <Svg height="16" width="16" viewBox="0 0 24 24">
        <Path fill="#8A8A8A" d="M4 6h16v2H4zm0 5h16v2H4zm0 5h16v2H4z"/>
    </Svg>
);

const LevelsIcon = () => (
    <Svg height="16" width="16" viewBox="0 0 24 24">
        <Path fill="#8A8A8A" d="M3 18h18v-2H3v2zm0-5h18v-2H3v2zm0-7v2h18V6H3z"/>
    </Svg>
);

const InfoIcon: React.FC<{path: string}> = ({path}) => (
    <Svg height="24" width="24" viewBox="0 0 24 24">
        <Path fill="#4A4A4A" d={path}/>
    </Svg>
);

// --- Data for Challenges ---
const challenges = [
  {
    key: 'riddles',
    Icon: RiddleIcon,
    title: 'Riddle Challenge',
    description: 'Brain teasers for logical thinking',
    details: [
      { Icon: ClockIcon, text: '~5 minutes total duration' },
      { Icon: ListIcon, text: '5 quick questions' },
      { Icon: LevelsIcon, text: 'For all ages' },
    ],
  },
  {
    key: 'math',
    Icon: MathIcon,
    title: 'Math Challenge',
    description: 'Quick sums to sharpen your focus',
    details: [
      { Icon: ClockIcon, text: '~3 minutes total duration' },
      { Icon: ListIcon, text: '10 quick questions' },
      { Icon: LevelsIcon, text: 'For all ages' },
    ],
  },
];

type Challenge = typeof challenges[0];

// --- Reusable Components ---
const ChallengeCard: React.FC<{ challenge: Challenge }> = ({ challenge }) => {
    const router = useRouter();
    
    const handleStart = () => {
        // You can uncomment this to navigate once the challenge screens are created
        // router.push(`/${challenge.key}`);
        Alert.alert('Challenge Started', `Starting ${challenge.title}`);
    };

    return (
        <View style={styles.card}>
            <View style={styles.cardHeader}>
                <View style={styles.cardIconBackground}>
                    <challenge.Icon />
                </View>
                <View style={styles.cardInfo}>
                    <Text style={styles.cardTitle}>{challenge.title}</Text>
                    <Text style={styles.cardDescription}>{challenge.description}</Text>
                </View>
            </View>
            <View style={styles.cardDetails}>
                {challenge.details.map((item, index) => (
                    <View key={index} style={styles.detailItem}>
                    <item.Icon />
                    <Text style={styles.detailText}>{item.text}</Text>
                    </View>
                ))}
            </View>
            <TouchableOpacity style={styles.startButton} onPress={handleStart}>
                <Text style={styles.startButtonText}>Start Challenge</Text>
            </TouchableOpacity>
        </View>
    );
};

// --- Main Screen Component ---
export default function GameScreen() {
  return (
    <SafeAreaView style={styles.safeArea}>
      <StatusBar barStyle="dark-content" backgroundColor={styles.safeArea.backgroundColor} />
      <ScrollView
        style={styles.container}
        contentContainerStyle={styles.contentContainer}
        showsVerticalScrollIndicator={false}
      >
        <View style={styles.introHeader}>
            <View style={styles.introIconContainer}>
                <PuzzleIcon color="#666" />
            </View>
            <Text style={styles.title}>Cognitive Warm-Up</Text>
            <Text style={styles.subtitle}>
            Activate your mind before deep focus sessions
            </Text>
        </View>

        {/* Challenges Section */}
        {challenges.map(challenge => (
            <ChallengeCard key={challenge.key} challenge={challenge} />
        ))}

        {/* Why Warm-Up? Section */}
        <View style={styles.infoSection}>
          <Text style={styles.infoTitle}>Why Warm-Up?</Text>
          <View style={styles.infoItem}>
             <InfoIcon path="M12 4c-4.41 0-8 3.59-8 8s3.59 8 8 8 8-3.59 8-8-3.59-8-8-8zm-1 12H9V8h2v8zm4 0h-2V8h2v8z" />
            <View style={styles.infoTextContainer}>
              <Text style={styles.infoItemTitle}>Mental Activation</Text>
              <Text style={styles.infoItemSub}>
                Prepares your brain for focused work
              </Text>
            </View>
          </View>
          <View style={styles.infoItem}>
            <InfoIcon path="M15 4V1h-6v3H4v6l3.45-3.45L12 11l4.55-4.55L20 10V4h-5zM4 14v6h5l-3.45-3.45L10 12l-4.55 4.55L2 20h6v-3h2v3h6v-6l-3.45 3.45L12 13l-4.55 4.55L4 14z"/>
            <View style={styles.infoTextContainer}>
              <Text style={styles.infoItemTitle}>Quick Transition</Text>
              <Text style={styles.infoItemSub}>
                Smooth shift into deep focus mode
              </Text>
            </View>
          </View>
          <View style={styles.infoItem}>
             <InfoIcon path="M11 18h2v-2h-2v2zm1-16C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8s8 3.59 8 8s-3.59 8-8 8zm0-14c-2.21 0-4 1.79-4 4h2c0-1.1.9-2 2-2s2 .9 2 2c0 2-3 1.75-3 5h2c0-2.25 3-2.5 3-5c0-2.21-1.79-4-4-4z"/>
            <View style={styles.infoTextContainer}>
              <Text style={styles.infoItemTitle}>Optional Enhancement</Text>
              <Text style={styles.infoItemSub}>
                Use when you need extra mental clarity
              </Text>
            </View>
          </View>
        </View>
      </ScrollView>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  safeArea: {
    flex: 1,
    backgroundColor: '#F4F4F7',
  },
  container: {
    flex: 1,
  },
  contentContainer: {
    padding: 20,
    paddingTop: 40, // Added padding to compensate for removed header
    paddingBottom: 40,
  },
  header: {
    alignItems: 'flex-start',
    marginBottom: 20,
  },
  introHeader: {
    alignItems: 'center',
    marginBottom: 24,
  },
  introIconContainer: {
    width: 60,
    height: 60,
    borderRadius: 30,
    backgroundColor: '#E8E8ED',
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 16,
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 8,
  },
  subtitle: {
    fontSize: 16,
    color: '#666',
    textAlign: 'center',
  },
  card: {
    backgroundColor: '#FFFFFF',
    borderRadius: 16,
    padding: 20,
    marginBottom: 16,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.05,
    shadowRadius: 8,
    elevation: 3,
  },
  cardHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 16,
  },
  cardIconBackground: {
    width: 48,
    height: 48,
    borderRadius: 12,
    backgroundColor: '#F4F4F7',
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 16,
  },
  cardInfo: {
    flex: 1,
  },
  cardTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#333',
  },
  cardDescription: {
    fontSize: 14,
    color: '#666',
    marginTop: 2,
  },
  cardDetails: {
    marginBottom: 20,
  },
  detailItem: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 8,
  },
  detailText: {
    marginLeft: 12,
    fontSize: 14,
    color: '#333',
  },
  startButton: {
    backgroundColor: '#333',
    paddingVertical: 14,
    borderRadius: 12,
    alignItems: 'center',
  },
  startButtonText: {
    color: '#FFFFFF',
    fontSize: 16,
    fontWeight: 'bold',
  },
  infoSection: {
    marginTop: 24,
  },
  infoTitle: {
    fontSize: 20,
    fontWeight: 'bold',
    marginBottom: 16,
    color: '#333',
  },
  infoItem: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 16,
  },
  infoTextContainer: {
    marginLeft: 16,
    flex: 1,
  },
  infoItemTitle: {
    fontSize: 16,
    fontWeight: '600',
    color: '#333',
  },
  infoItemSub: {
    fontSize: 14,
    color: '#666',
  },
});

