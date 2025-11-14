import { ElderlyReportEntity } from '../entity/viewReportsCaregiverEntity';
import { ref, get } from "firebase/database";
import { database } from "../firebaseConfig";
import { emailToKey } from "../controller/appointmentController";
import jsPDF from 'jspdf';
import html2canvas from 'html2canvas';

export class ViewReportsCaregiverController {
  constructor() {}

  // Convert email to Firebase-safe key
  emailToKey(email) {
    return email ? email.replace(/\./g, '_').toLowerCase() : '';
  }

  // Enhanced function to fetch elderly data using identifier (email or UID)
  async fetchElderlyData(elderlyIdentifier) {
    try {
      let elderlyRef;
      
      // Check if identifier is an email (contains @)
      if (elderlyIdentifier.includes('@')) {
        const key = this.emailToKey(elderlyIdentifier);
        elderlyRef = ref(database, `Account/${key}`);
      } else {
        // Identifier is likely a UID, search through all accounts
        elderlyRef = ref(database, 'Account');
      }
      
      const snapshot = await get(elderlyRef);
      
      if (!snapshot.exists()) {
        console.error(`Elderly not found in Firebase with identifier: ${elderlyIdentifier}`);
        throw new Error('Elderly data not found in database');
      }

      let elderly;
      
      if (elderlyIdentifier.includes('@')) {
        // Direct lookup by email key
        elderly = snapshot.val();
      } else {
        // Search for UID in all accounts
        const allAccounts = snapshot.val();
        elderly = Object.values(allAccounts).find(account => 
          account.uid === elderlyIdentifier || 
          account.email === elderlyIdentifier
        );
        
        if (!elderly) {
          throw new Error('Elderly user not found with the provided identifier');
        }
      }
      
      if (!elderly.firstname || !elderly.lastname || !elderly.dob) {
        console.error('Incomplete elderly data:', elderly);
        throw new Error('Elderly data is incomplete');
      }
      
      const dob = new Date(elderly.dob);
      const today = new Date();
      let age = today.getFullYear() - dob.getFullYear();
      const monthDiff = today.getMonth() - dob.getMonth();
      if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < dob.getDate())) age--;

      return {
        id: elderlyIdentifier.includes('@') ? this.emailToKey(elderlyIdentifier) : elderlyIdentifier,
        identifier: elderlyIdentifier,
        name: `${elderly.firstname} ${elderly.lastname}`,
        age,
        email: elderly.email || elderlyIdentifier,
        uid: elderly.uid || elderlyIdentifier,
      };
    } catch (error) {
      console.error('Error fetching elderly data:', error);
      throw new Error(`Failed to fetch elderly data: ${error.message}`);
    }
  }

  // Get all elderly identifiers from caregiver's data (supports multiple field names)
  getAllElderlyIdentifiersFromCaregiver(caregiverData) {
    const elderlyIdentifiers = [];
    
    // Check all possible field names for elderly connections
    const possibleFields = [
      'elderlyIds',        // Array of emails/UIDs
            // Array of emails/UIDs
      'elderlyId',         // Single email/UID
              // Single UID
    ];
    
    possibleFields.forEach(field => {
      if (caregiverData[field]) {
        if (Array.isArray(caregiverData[field])) {
          // Handle array fields
          caregiverData[field].forEach(id => {
            if (id && !elderlyIdentifiers.includes(id)) {
              elderlyIdentifiers.push(id);
            }
          });
        } else if (typeof caregiverData[field] === 'string' && caregiverData[field].trim()) {
          // Handle single string fields
          if (!elderlyIdentifiers.includes(caregiverData[field])) {
            elderlyIdentifiers.push(caregiverData[field]);
          }
        }
      }
    });
    
    console.log('Found elderly identifiers:', elderlyIdentifiers);
    return elderlyIdentifiers;
  }

  // Generate sample reports for an elderly
  generateReportsData(elderlyName = 'Elderly') {
    return [
      {
        id: 1,
        category: 'health',
        title: 'Health Vitals',
        icon: '💗',
        iconClass: 'health-icon',
        chartData: {
          labels: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
          datasets: [
            {
              label: 'Systolic',
              data: [125, 120, 118, 122, 119, 121, 120],
              borderColor: '#ff6b6b',
              backgroundColor: 'rgba(255, 107, 107, 0.1)',
              tension: 0.4,
            },
            {
              label: 'Diastolic',
              data: [82, 80, 76, 81, 78, 80, 80],
              borderColor: '#4ecdc4',
              backgroundColor: 'rgba(78, 205, 196, 0.1)',
              tension: 0.4,
            },
          ],
        },
        stats: [
          { number: '120/80', label: 'Blood Pressure' },
          { number: 72, label: 'Heart Rate' },
        ],
      },
      {
        id: 2,
        category: 'medication',
        title: 'Medication Adherence',
        icon: '💊',
        iconClass: 'medication-icon',
        chartData: {
          labels: ['Taken', 'Missed', 'Scheduled'],
          datasets: [{ data: [28, 2, 5], backgroundColor: ['#4ecdc4', '#ff6b6b', '#feca57'] }],
        },
        stats: [
          { number: '95%', label: 'This Week' },
          { number: 2, label: 'Missed Doses' },
        ],
      },
      {
        id: 3,
        category: 'activity',
        title: 'Daily Activities',
        icon: '🚶',
        iconClass: 'activity-icon',
        chartData: {
          labels: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
          datasets: [
            {
              label: 'Steps',
              data: [2800, 3200, 2950, 4200, 3800, 2100, 3240],
              backgroundColor: 'rgba(69, 183, 209, 0.8)',
              borderColor: '#45b7d1',
              borderWidth: 2,
              borderRadius: 5,
            },
          ],
        },
        stats: [
          { number: 3240, label: 'Steps Today' },
          { number: 7.5, label: 'Sleep Hours' },
        ],
      },
      {
        id: 4,
        category: 'emergency',
        title: 'Emergency Alerts',
        icon: '🚨',
        iconClass: 'emergency-icon',
        chartData: {
          labels: ['Week 1', 'Week 2', 'Week 3', 'Week 4'],
          datasets: [
            {
              label: 'Alerts',
              data: [0, 1, 0, 0],
              borderColor: '#f093fb',
              backgroundColor: 'rgba(240, 147, 251, 0.1)',
              tension: 0.4,
              fill: true,
            },
          ],
        },
        stats: [
          { number: 0, label: 'This Week' },
          { number: 1, label: 'This Month' },
        ],
      },
    ];
  }

  // Generate alerts for an elderly
  generateAlertsData(elderlyName) {
    return [
      {
        id: 1,
        type: 'warning',
        title: 'Medication Reminder',
        time: '2 hours ago',
        message: `${elderlyName} missed afternoon medication.`,
      },
      {
        id: 2,
        type: 'info',
        title: 'Activity Update',
        time: '5 hours ago',
        message: `${elderlyName} walked 4,200 steps today.`,
      },
      {
        id: 3,
        type: 'info',
        title: 'Health Check',
        time: '1 day ago',
        message: `Blood pressure reading recorded for ${elderlyName}: 118/76 mmHg.`,
      },
    ];
  }

  // Fetch caregiver data from database
  async fetchCaregiverData(caregiverEmail) {
    try {
      const key = this.emailToKey(caregiverEmail);
      const snapshot = await get(ref(database, `Account/${key}`));
      
      if (!snapshot.exists()) {
        throw new Error('Caregiver data not found in database');
      }
      
      return snapshot.val();
    } catch (error) {
      console.error('Error fetching caregiver data:', error);
      throw new Error(`Failed to fetch caregiver data: ${error.message}`);
    }
  }

  // Main function to get all data for caregiver (supports multiple elderly)
  async getElderlyReportData(currentUser) {
    try {
      const loggedInEmail = localStorage.getItem('loggedInEmail');
      const email = (loggedInEmail || currentUser?.email || "").toLowerCase();
      if (!email) throw new Error("No logged-in user found. Please log in again.");
      
      // Check user type
      const userType = currentUser?.userType || localStorage.getItem('userType');
      if (userType !== 'caregiver') throw new Error("Only caregivers can view reports");

      // Fetch complete caregiver data from database
      const caregiverData = await this.fetchCaregiverData(email);
      
      // Get all elderly identifiers (both emails and UIDs)
      const elderlyIdentifiers = this.getAllElderlyIdentifiersFromCaregiver(caregiverData);
      
      console.log('Found elderly identifiers:', elderlyIdentifiers);
      
      // If no elderly identifiers found, use demo data
      if (elderlyIdentifiers.length === 0) {
        console.warn('No elderly identifiers found, using demo data');
        return [ElderlyReportEntity.fromJson({
          id: 'demo-elderly',
          identifier: 'demo@example.com',
          name: 'Demo Elderly',
          age: 75,
          email: 'demo@example.com',
          uid: 'demo-uid',
          reports: this.generateReportsData('Demo Elderly'),
          alerts: this.generateAlertsData('Demo Elderly')
        })];
      }

      // Fetch data for all elderly users
      const elderlyReportData = [];
      
      for (const elderlyIdentifier of elderlyIdentifiers) {
        try {
          const elderlyData = await this.fetchElderlyData(elderlyIdentifier);
          const reports = this.generateReportsData(elderlyData.name);
          const alerts = this.generateAlertsData(elderlyData.name);

          elderlyReportData.push(ElderlyReportEntity.fromJson({
            id: elderlyData.id,
            identifier: elderlyData.identifier,
            name: elderlyData.name,
            age: elderlyData.age,
            email: elderlyData.email,
            uid: elderlyData.uid,
            reports,
            alerts
          }));
        } catch (error) {
          console.error(`Error fetching data for elderly ${elderlyIdentifier}:`, error);
          // Continue with next elderly even if one fails
        }
      }

      // If all elderly data fetches failed, return demo data
      if (elderlyReportData.length === 0) {
        console.warn('All elderly data fetches failed, using demo data');
        return [ElderlyReportEntity.fromJson({
          id: 'demo-elderly',
          identifier: 'demo@example.com',
          name: 'Demo Elderly',
          age: 75,
          email: 'demo@example.com',
          uid: 'demo-uid',
          reports: this.generateReportsData('Demo Elderly'),
          alerts: this.generateAlertsData('Demo Elderly')
        })];
      }

      return elderlyReportData;

    } catch (error) {
      console.error('Error in getElderlyReportData:', error);
      
      // Provide demo data as fallback in case of error
      console.warn('Using demo data due to error:', error.message);
      return [ElderlyReportEntity.fromJson({
        id: 'demo-elderly',
        identifier: 'demo@example.com',
        name: 'Demo Elderly',
        age: 75,
        email: 'demo@example.com',
        uid: 'demo-uid',
        reports: this.generateReportsData('Demo Elderly'),
        alerts: this.generateAlertsData('Demo Elderly')
      })];
    }
  }

  async exportReportsAsPDF(selectedElderly) {
    try {
      if (!selectedElderly) {
        alert('Please select an elderly to export reports');
        return;
      }

      // Get the reports container element
      const reportsElement = document.querySelector('.reports-grid');
      
      if (!reportsElement) {
        alert('No reports found to export');
        return;
      }
      
      // Create a new PDF document
      const pdf = new jsPDF('p', 'mm', 'a4');
      const pageWidth = pdf.internal.pageSize.getWidth();
      const pageHeight = pdf.internal.pageSize.getHeight();
      
      // Add title
      pdf.setFontSize(20);
      pdf.text('Elderly Care Reports', pageWidth / 2, 15, { align: 'center' });
      
      // Add elderly info
      pdf.setFontSize(12);
      pdf.text(`${selectedElderly.name} (Age: ${selectedElderly.age})`, pageWidth / 2, 25, { align: 'center' });
      
      // Add identifier info
      pdf.setFontSize(10);
      const identifier = selectedElderly.identifier || selectedElderly.email || selectedElderly.uid;
      pdf.text(`ID: ${identifier}`, pageWidth / 2, 32, { align: 'center' });
      
      // Add date
      const date = new Date().toLocaleDateString();
      pdf.text(`Generated on: ${date}`, pageWidth / 2, 39, { align: 'center' });
      
      // Capture each report card as an image and add to PDF
      const reportCards = reportsElement.querySelectorAll('.report-card');
      let yPosition = 50;
      
      for (let i = 0; i < reportCards.length; i++) {
        const card = reportCards[i];
        
        // Create a canvas from the report card
        const canvas = await html2canvas(card, {
          scale: 2, // Higher quality
          useCORS: true,
          allowTaint: true
        });
        
        const imgData = canvas.toDataURL('image/jpeg', 0.9);
        const imgWidth = pageWidth - 20; // Margin of 10mm on each side
        const imgHeight = (canvas.height * imgWidth) / canvas.width;
        
        // Check if we need a new page
        if (yPosition + imgHeight > pageHeight - 10) {
          pdf.addPage();
          yPosition = 20;
        }
        
        // Add the image to the PDF
        pdf.addImage(imgData, 'JPEG', 10, yPosition, imgWidth, imgHeight);
        yPosition += imgHeight + 10;
      }
      
      // Add alerts section if there are any alerts
      const alerts = document.querySelectorAll('.alert-card');
      if (alerts.length > 0) {
        // Check if we need a new page
        if (yPosition > pageHeight - 50) {
          pdf.addPage();
          yPosition = 20;
        }
        
        pdf.setFontSize(16);
        pdf.text('Recent Alerts & Notifications', 10, yPosition);
        yPosition += 10;
        
        pdf.setFontSize(10);
        alerts.forEach(alert => {
          const title = alert.querySelector('.alert-header strong')?.textContent || '';
          const time = alert.querySelector('.alert-time')?.textContent || '';
          const message = alert.querySelector('p')?.textContent || '';
          
          // Check if we need a new page
          if (yPosition > pageHeight - 20) {
            pdf.addPage();
            yPosition = 20;
          }
          
          pdf.setFontSize(12);
          pdf.text(`${title} (${time})`, 10, yPosition);
          yPosition += 7;
          
          pdf.setFontSize(10);
          const splitMessage = pdf.splitTextToSize(message, pageWidth - 20);
          pdf.text(splitMessage, 10, yPosition);
          yPosition += splitMessage.length * 5 + 10;
        });
      }
      
      // Save the PDF
      const fileName = `reports-${selectedElderly.name.replace(/\s+/g, '-').toLowerCase()}-${new Date().toISOString().split('T')[0]}.pdf`;
      pdf.save(fileName);
      
    } catch (error) {
      console.error('Error generating PDF:', error);
      alert('Failed to generate PDF. Please try again.');
    }
  }
}

export default ViewReportsCaregiverController;