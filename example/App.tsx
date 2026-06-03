import { View, StyleSheet, ScrollView, Alert, Text, SafeAreaView, Pressable } from 'react-native';
import MobileConsent, { type ConsentItem } from '@cookieinformation/react-native-sdk';
import React, { useEffect, useState } from 'react';

interface ConsentItemDisplay {
  id: number | string;
  universalId?: string;
  title: string;
  description?: string;
  required?: boolean;
  type?: string;
  accepted?: boolean;
}

function formatError(e: unknown): string {
  return e instanceof Error ? e.message : String(e);
}

const { initialize, showPrivacyPopUp, showPrivacyPopUpIfNeeded, acceptAllConsents, removeStoredConsents, cacheConsentSolution, synchronizeIfNeeded, getSavedConsents, saveConsents } = MobileConsent;

export default function App() {
  const [statusNote, setStatusNote] = useState<string>('Standing by');
  const [consentInfo, setConsentInfo] = useState<ConsentItemDisplay[] | null>(null);

  useEffect(() => {
    /*
    // Example: initialize with UI customization
    initialize({
      clientId: 'YOUR_CLIENT_ID',
      clientSecret: 'YOUR_CLIENT_SECRET',
      solutionId: 'YOUR_SOLUTION_ID',
      languageCode: 'EN',
      enableNetworkLogger: true,
      ui: {
        ios: {
          accentColor: '#FF0000',
          fontSet: {
            largeTitle: { size: 34, weight: 'bold' },
            body: { size: 34, weight: 'regular' },
            bold: { size: 34, weight: 'bold' },
          },
        },
        android: {
          lightColorScheme: {
            primary: '#FF0000',
            secondary: '#FFFF00',
            tertiary: '#FFC0CB',
          },
          darkColorScheme: {
            primary: '#00FF00',
            secondary: '#008000',
            tertiary: '#000000',
          },
          typography: {
            bodyMedium: { font: 'inter_regular', size: 14 },
          },
        },
      },
    })
      .then(() => setStatusNote('SDK initialized'))
      .catch((e) => {
        console.error('Initialize error:', e);
        setStatusNote('Init failed');
        Alert.alert('Issue', `Unable to initialize SDK: ${e}`);
      });
    */

    initialize({
      clientId: 'YOUR_CLIENT_ID',
      clientSecret: 'YOUR_CLIENT_SECRET',
      solutionId: 'YOUR_SOLUTION_ID',
      languageCode: 'EN',
      enableNetworkLogger: true,
    })
      .then(() => setStatusNote('SDK initialized'))
      .catch((e: unknown) => {
        console.error('Initialize error:', e);
        setStatusNote('Init failed');
        Alert.alert('Issue', `Unable to initialize SDK: ${formatError(e)}`);
      });
  }, []);

  const runAcceptAll = async () => {
    try {
      const result = await acceptAllConsents();
      console.log('Accept all response:', result);
      const consentsList = Array.isArray(result?.consents) ? result.consents : null;
      const consentNames = consentsList
        ? consentsList.map((c: ConsentItem) => c.title).join(', ')
        : Object.keys(result ?? {}).join(', ');
      const savedCount = consentsList ? result.count : Object.keys(result ?? {}).length;

      setStatusNote(`Saved ${savedCount} items`);
      Alert.alert(
        'All set',
        `Saved ${savedCount} consents:\n${consentNames}`
      );
    } catch (e: unknown) {
      console.error('Accept all error:', e);
      setStatusNote('Accept all failed');
      Alert.alert('Issue', `Unable to save consents: ${formatError(e)}`);
    }
  };

  const runConsentDialog = async () => {
    try {
      const result = await showPrivacyPopUp();
      console.log('Consent dialog outcome:', result);
      setStatusNote('Consent dialog finished');
      setTimeout(() => {
        Alert.alert('Done', 'Consent dialog completed');
      }, 300);
    } catch (e: unknown) {
      console.error('Consent dialog error:', e);
      setStatusNote('Consent dialog failed');
      Alert.alert('Issue', `Unable to open consent dialog: ${formatError(e)}`);
    }
  };

  const runConsentIfNeeded = async () => {
    try {
      const result = await showPrivacyPopUpIfNeeded();
      console.log('Consent if needed outcome:', result);
      setStatusNote('Consent check finished');
      setTimeout(() => {
        Alert.alert('Done', 'Consent flow completed (pop-up shown only if needed).');
      }, 300);
    } catch (e: unknown) {
      console.error('Consent if needed error:', e);
      setStatusNote('Consent check failed');
      Alert.alert('Issue', `Unable to run consent check: ${formatError(e)}`);
    }
  };

  const runRemoveStoredConsents = async () => {
    try {
      await removeStoredConsents();
      console.log('Stored consents removed');
      setStatusNote('Local consents removed');
      setConsentInfo(null);
      Alert.alert('Done', 'Stored consents have been removed from this device.');
    } catch (e: unknown) {
      console.error('Remove stored consents error:', e);
      setStatusNote('Remove failed');
      Alert.alert('Issue', `Unable to remove stored consents: ${formatError(e)}`);
    }
  };

  const runSynchronizeIfNeeded = async () => {
    try {
      await synchronizeIfNeeded();
      setStatusNote('Sync finished');
      Alert.alert('Done', 'Consent sync completed.');
    } catch (e: unknown) {
      console.error('Sync error:', e);
      setStatusNote('Sync failed');
      Alert.alert('Issue', `Unable to sync consents: ${formatError(e)}`);
    }
  };

  const runCacheConsentSolution = async () => {
    try {
      const consentItems = await cacheConsentSolution();
      const items = Array.isArray(consentItems) ? consentItems : [];
      const count = items.length;
      setStatusNote(`Cached ${count} consent item(s)`);
      setConsentInfo(items as ConsentItemDisplay[]);
      Alert.alert('Done', `Consent solution cached. ${count} item(s) available.`);
    } catch (e: unknown) {
      console.error('Cache consent solution error:', e);
      setStatusNote('Cache failed');
      setConsentInfo(null);
      Alert.alert('Issue', `Unable to cache consent solution: ${formatError(e)}`);
    }
  };

  const runGetSavedConsents = async () => {
    try {
      const consentItems = await getSavedConsents();
      const items = Array.isArray(consentItems) ? consentItems : [];
      const count = items.length;
      setStatusNote(`Read ${count} saved consent(s)`);
      setConsentInfo(items as ConsentItemDisplay[]);
      Alert.alert('Done', `${count} consent(s) in local storage.`);
    } catch (e: unknown) {
      console.error('Get saved consents error:', e);
      setStatusNote('Read failed');
      setConsentInfo(null);
      Alert.alert('Issue', `Unable to read saved consents: ${formatError(e)}`);
    }
  };

  const runPostConsentManually = async () => {
    try {
      const items = consentInfo ?? [];
      if (items.length === 0) {
        Alert.alert('No data', 'Cache or load saved consents first, then tap "Save consents manually".');
        return;
      }
      const customData = { device_id: 'example-device' } as Record<string, string>;
      const result = await saveConsents(items as ConsentItem[], customData, null);
      const count = result?.savedCount ?? items.length;
      setStatusNote(`Consent saved (${count} item(s))`);
      Alert.alert('Done', `Consent sent to the server. Saved ${count} item(s).`);
    } catch (e: unknown) {
      console.error('Save consents error:', e);
      setStatusNote('Save consents failed');
      Alert.alert('Issue', `Unable to save consents: ${formatError(e)}`);
    }
  };

  const actions = [
    { title: 'Open Consent Dialog', subtitle: 'Show privacy options', onPress: runConsentDialog },
    { title: 'Show consent if needed', subtitle: 'Show pop-up only when no consent or version changed', onPress: runConsentIfNeeded },
    { title: 'Cache consent solution', subtitle: 'Fetch from server and save to local DB', onPress: runCacheConsentSolution },
    { title: 'Read saved consents', subtitle: 'Load consent items from local storage', onPress: runGetSavedConsents },
    { title: 'Sync consents', subtitle: 'Retry failed consent uploads', onPress: runSynchronizeIfNeeded },
    { title: 'Save consents manually', subtitle: 'Send consent to server (build payload from cached/saved items)', onPress: runPostConsentManually },
    { title: 'Accept Everything', subtitle: 'Save full consent set', onPress: runAcceptAll },
    { title: 'Remove stored consents', subtitle: 'Clear local consent data from this device', onPress: runRemoveStoredConsents },
  ];

  return (
    <SafeAreaView style={styles.screen}>
      <ScrollView contentContainerStyle={styles.contentContainer}>
        <View style={styles.header}>
          <Text style={styles.title}>Consent Workspace</Text>
          <Text style={styles.subtitle}>Tools for managing consent actions</Text>
        </View>

        <View style={styles.statusCard}>
          <Text style={styles.statusLabel}>Latest status</Text>
          <Text style={styles.statusValue}>{statusNote}</Text>
        </View>

        <Text style={styles.sectionTitle}>Quick Actions</Text>
        <View style={styles.actionGrid}>
          {actions.map((item) => (
            <Pressable key={item.title} style={styles.actionCard} onPress={item.onPress}>
              <Text style={styles.actionTitle}>{item.title}</Text>
              <Text style={styles.actionSubtitle}>{item.subtitle}</Text>
            </Pressable>
          ))}
        </View>

        {consentInfo != null && consentInfo.length > 0 && (
          <>
            <Text style={styles.sectionTitle}>Cached consent items</Text>
            <View style={styles.consentInfoCard}>
              <Text style={styles.consentInfoSummary}>
                {consentInfo.length} item(s): {consentInfo.map((c) => c.title).join(', ')}
              </Text>
              {consentInfo.map((c, i) => (
                <View key={i} style={styles.consentInfoRow}>
                  <Text style={styles.consentInfoTitle}>{c.title}</Text>
                  <Text style={styles.consentInfoMeta}>
                    type: {c.type ?? '—'} · required: {c.required ? 'yes' : 'no'}
                    {c.accepted != null ? ` · accepted: ${c.accepted}` : ''}
                  </Text>
                  {c.description ? (
                    <Text style={styles.consentInfoDesc} numberOfLines={2}>{c.description}</Text>
                  ) : null}
                </View>
              ))}
            </View>
          </>
        )}

      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  screen: {
    flex: 1,
    backgroundColor: '#0f172a',
  },
  contentContainer: {
    padding: 20,
    paddingBottom: 32,
  },
  header: {
    padding: 16,
    backgroundColor: '#111827',
    borderRadius: 16,
    borderWidth: 1,
    borderColor: '#1f2937',
    marginBottom: 16,
  },
  title: {
    fontSize: 24,
    fontWeight: '700',
    color: '#f8fafc',
  },
  subtitle: {
    marginTop: 4,
    fontSize: 13,
    color: '#94a3b8',
  },
  statusCard: {
    padding: 16,
    borderRadius: 16,
    backgroundColor: '#0b1220',
    borderWidth: 1,
    borderColor: '#1f2937',
    marginBottom: 18,
  },
  statusLabel: {
    fontSize: 12,
    textTransform: 'uppercase',
    letterSpacing: 1,
    color: '#64748b',
  },
  statusValue: {
    marginTop: 8,
    fontSize: 14,
    color: '#e2e8f0',
  },
  sectionTitle: {
    fontSize: 14,
    fontWeight: '600',
    color: '#e2e8f0',
    marginBottom: 10,
  },
  actionGrid: {
    gap: 12,
    marginBottom: 20,
  },
  actionCard: {
    padding: 14,
    borderRadius: 14,
    backgroundColor: '#334155',
    borderWidth: 1,
    borderColor: '#475569',
  },
  actionTitle: {
    fontSize: 15,
    fontWeight: '600',
    color: '#f8fafc',
  },
  actionSubtitle: {
    marginTop: 4,
    fontSize: 12,
    color: '#cbd5e1',
  },
  consentInfoCard: {
    padding: 16,
    borderRadius: 16,
    backgroundColor: '#1e293b',
    borderWidth: 1,
    borderColor: '#334155',
    marginBottom: 20,
  },
  consentInfoSummary: {
    fontSize: 13,
    color: '#cbd5e1',
    marginBottom: 12,
  },
  consentInfoRow: {
    marginBottom: 12,
    paddingBottom: 12,
    borderBottomWidth: 1,
    borderBottomColor: '#334155',
  },
  consentInfoTitle: {
    fontSize: 14,
    fontWeight: '600',
    color: '#f8fafc',
  },
  consentInfoMeta: {
    fontSize: 11,
    color: '#94a3b8',
    marginTop: 4,
  },
  consentInfoDesc: {
    fontSize: 12,
    color: '#cbd5e1',
    marginTop: 4,
    lineHeight: 16,
  },
  infoText: {
    fontSize: 12,
    color: '#cbd5f5',
    lineHeight: 16,
  },
});