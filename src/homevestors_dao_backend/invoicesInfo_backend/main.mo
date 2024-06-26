import Hash "mo:base/Hash";
import Float "mo:base/Float";
import Result "mo:base/Result";
import HashMap "mo:base/HashMap";
//import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Buffer "mo:base/Buffer";
import Time "mo:base/Time";
import { setTimer; recurringTimer } = "mo:base/Timer";
import Int "mo:base/Int";
import Types "types";
import InvoiceTypes "./../invoices_backend/types";


actor {
    type Result <Ok, Err> = Types.Result<Ok,Err>;
    type HashMap<K,V> = Types.HashMap<K,V>; 

    type InvoicesInfo = Types.InvoicesInfo; 
    type AllInvoicesOfStatus = Types.AllInvoicesOfStatus;
    type InvoiceReccurringSummary = Types.InvoiceReccurringSummary;
    type InvoicesPaidThisTaxYear = Types.InvoicesPaidThisTaxYear;
    type InvoiceTotalsToDate = Types.InvoiceTotalsToDate;
    type InvoiceTaxByYear = Types.InvoiceTaxByYear;

    type Invoice = InvoiceTypes.Invoice;
    type InvoiceCategory = InvoiceTypes.InvoiceCategory;

    let invoices_backend : actor {
		listAllPropertyInvoices : shared (companyId : Nat) -> async [Invoice]; 
	} = actor ("bd3sg-teaaa-aaaaa-qaaba-cai"); 

    let invoicesInfo = HashMap.HashMap<Nat, InvoicesInfo>(0, Nat.equal, Hash.hash);

    ///////////////////////////////////////////////////////////////
///Invoices Info below Here
///////////////////////////////////////////////////////////////
//Okay so lets create InvoiceInfo
//Make it into a stable hashmap type datastructure
//Essentially initially create it with all either empty arrays or 0's.
//Every time an invoice is created, status changed or paid the function that creates AllInvoicesOfStatus would need to be called
//Every time an open invoice becomes approved call function that creates invoiceRecurringSummary
//Every time an invoice is paid InvoiceTotalsToDate would need to be called
//

public func createInvoicesInfo (companyId : Nat): async (){
  let paymentsToDate : InvoiceTotalsToDate = {
      mortgage = 0;
      maintenanceTaxExempt = 0;
      maintenanceNonTaxExempt = 0;
      management = 0;
      rentRecieved = 0; 
      hVDTokensRecieved = 0;
      hVDCashInRecieved = 0;
      investmentsMade = 0;
      dividendsRecieved = 0; 
      totalTaxPaid =0;
  };
  let annualCashflow : InvoicesPaidThisTaxYear = {
      annualIncomeRent = 0;
      annualIncomeSellingHVD = 0;
      annualMaintenanceTaxExempt = 0; 
      annualMaintenanceTaxNonExempt = 0;
      annualManagement = 0;
      annualMortgage = 0; 
      annualOther = 0;
  };
  let reccurringSummary : InvoiceReccurringSummary = {
      approvedRecurringExpenses = [];
      recurringIncome = [];
      monthlyRecurringExpenses = 0; 
      monthlyRecurringIncome = 0; 
      hVDTokensRecievedperMonth = 0;
  }; 

  let allOfStatus : AllInvoicesOfStatus = {
      openInvoices = [];
      approvedInvoices = [];
      rejectedInvoices = [];
      paidInvoices = [];
      recievedInvoices = [];
      maintenanceInvoices = [];
      investmentInvoices = [];
  }; 

  let newInvoiceInfo : InvoicesInfo = {
    companyId; 
    allOfStatus;
    reccurringSummary; 
    annualCashflow;
    paymentsToDate;
    allPropertyInvoices = [];
    taxByYear = [];
  }; 

  invoicesInfo.put(companyId, newInvoiceInfo);
};

public func getInvoiceInfo (companyId : Nat): async Result<InvoicesInfo,Text> {
  switch (invoicesInfo.get(companyId)){
    case(null){
      return #err("There is no company with that id");
    }; 
    case(? invoiceInfo){
      return #ok(invoiceInfo);
    };
  };
};

public func updateAllInvoicesOfStatus (companyId : Nat): async Result<(),Text> {
  switch(invoicesInfo.get(companyId)){
    case(null){
      return #err("There is no company with that id");
    };
    case(? invoiceInfo){
        let allPropertyInvoices = await invoices_backend.listAllPropertyInvoices(companyId);
        let allPropertyInvoicesBuffer = Buffer.fromArray<Invoice>(allPropertyInvoices);

        let open = Buffer.mapFilter<Invoice, Invoice>(allPropertyInvoicesBuffer, func (x) { if (x.status == #Open) { ?(x) } else { null }});
        let openInvoices = Buffer.toArray(open);

        let approved = Buffer.mapFilter<Invoice, Invoice>(allPropertyInvoicesBuffer, func (x) { if (x.status == #Approved) { ?(x) } else { null }});
        let approvedInvoices = Buffer.toArray(approved);

        let rejected = Buffer.mapFilter<Invoice, Invoice>(allPropertyInvoicesBuffer, func (x) { if (x.status == #Rejected) { ?(x) } else { null }});   
        let rejectedInvoices = Buffer.toArray(rejected);

        let paid = Buffer.mapFilter<Invoice, Invoice>(allPropertyInvoicesBuffer, func (x) { if (x.status == #Paid and x.cashflow == #Expense) { ?(x) } else { null }});
        let paidInvoices = Buffer.toArray(paid);

        let recieved = Buffer.mapFilter<Invoice, Invoice>(allPropertyInvoicesBuffer, func (x) { if (x.status == #Paid and x.cashflow == #Income) { ?(x) } else { null }});
        let recievedInvoices = Buffer.toArray(recieved);

        let maintenance = Buffer.mapFilter<Invoice, Invoice>(allPropertyInvoicesBuffer, func (x) { if (x.category == #MaintenanceTaxExempt or x.category == #MaintenanceNonTaxExempt) { ?(x) } else { null }});
        let maintenanceInvoices = Buffer.toArray(maintenance);

        let investment = Buffer.mapFilter<Invoice, Invoice>(allPropertyInvoicesBuffer, func (x) { if (x.category == #Investment) { ?(x) } else { null }});
        let investmentInvoices = Buffer.toArray(investment);

        let allOfStatus : AllInvoicesOfStatus = {
          openInvoices;
          approvedInvoices;
          rejectedInvoices;
          paidInvoices;
          recievedInvoices;
          maintenanceInvoices;
          investmentInvoices;
        };

        let newInvoiceInfo : InvoicesInfo = {
          companyId;
          allOfStatus;
          reccurringSummary = invoiceInfo.reccurringSummary;
          annualCashflow = invoiceInfo.annualCashflow;
          paymentsToDate = invoiceInfo.paymentsToDate;
          allPropertyInvoices;
          taxByYear = invoiceInfo.taxByYear;

        };

        invoicesInfo.put(companyId, newInvoiceInfo);
        return #ok();
    };
  };
};

public func updateInvoiceRecurringSummary (companyId : Nat): async Result<(),Text> {
  switch(invoicesInfo.get(companyId)){
    case(null){
      return #err("There is no company with that id");
    };
    case(? invoiceInfo){
      if(invoiceInfo.allPropertyInvoices.size()==0){
        return #err("There are no invoices for this company");
      };
      let allInvoices = Buffer.fromArray<Invoice>(invoiceInfo.allPropertyInvoices);
        
      let approvedRecurringExpensesBuffer = Buffer.mapFilter<Invoice, Invoice>(allInvoices, func (x) { if (x.content.recurring != null and x.status == #Approved and x.content.currency == #CKUSDC and x.cashflow == #Expense) { ?(x) } else { null }});
      let approvedRecurringExpenses = Buffer.toArray(approvedRecurringExpensesBuffer);

      let approvedRecurringIncomeBuffer = Buffer.mapFilter<Invoice, Invoice>(allInvoices, func (x) { if (x.content.recurring != null and x.status == #Approved and x.content.currency == #CKUSDC and x.cashflow == #Income) { ?(x) } else { null }});
      let recurringIncome = Buffer.toArray(approvedRecurringIncomeBuffer);
      
      var monthlyRecurringExpenses = 0.0;
      for(vals in approvedRecurringExpensesBuffer.vals()){
        switch(vals.content.recurring){
          case(null){
            return #err("A non recurring invoice is in the recurring list!");
          };
          case(? recurring){
            switch(recurring.frequency){
              case(#Weekly){
                monthlyRecurringExpenses += vals.content.amount*4.5;
              };
              case(#Monthly){
                monthlyRecurringExpenses += vals.content.amount;
              };
              case(#BiAnnually){
                monthlyRecurringExpenses += vals.content.amount/6;
              };
              case(#Annually){
                monthlyRecurringExpenses += vals.content.amount/12;
              };
            };
          };
        };
        };

    var monthlyRecurringIncome = 0.0;
      for(vals in approvedRecurringIncomeBuffer.vals()){
        switch(vals.content.recurring){
          case(null){
            return #err("A non recurring invoice is in the recurring list!");
          };
          case(? recurring){
            switch(recurring.frequency){ 
              case(#Weekly){
                monthlyRecurringIncome += vals.content.amount*4.5;
              };
              case(#Monthly){
                monthlyRecurringIncome += vals.content.amount;
              };
              case(#BiAnnually){
                monthlyRecurringIncome += vals.content.amount/6;
              };
              case(#Annually){
                monthlyRecurringIncome += vals.content.amount/12;
              };
            };
          };
        };  
    };

    let reccurringSummary : InvoiceReccurringSummary = {
      approvedRecurringExpenses;
      recurringIncome;
      monthlyRecurringExpenses;
      monthlyRecurringIncome;
      hVDTokensRecievedperMonth = 0.0; //This needs a bit more thought
    };

    let newInvoicesInfo : InvoicesInfo = {
      companyId;
      allOfStatus = invoiceInfo.allOfStatus;
      reccurringSummary;
      annualCashflow = invoiceInfo.annualCashflow;
      paymentsToDate = invoiceInfo.paymentsToDate;
      allPropertyInvoices = invoiceInfo.allPropertyInvoices;
      taxByYear = invoiceInfo.taxByYear;
    }; 

  invoicesInfo.put(companyId, newInvoicesInfo);
  return #ok();
};
};
};

public func updatePaidInvoiceTotals (companyId: Nat, amount : Float, category : InvoiceCategory):async Result<(), Text>{
  switch(invoicesInfo.get(companyId)){
    case(null){
      return #err("There is no company with that Id");
    };
    case(? invoiceInfo){
      var mortgage : Float= 0;
      var maintenanceTaxExempt : Float = 0;
      var maintenanceNonTaxExempt : Float = 0;
      var management : Float= 0;
      var rentRecieved : Float= 0;
      var hVDTokensRecieved : Float= 0;
      var hVDCashInRecieved : Float = 0;
      var investmentsMade : Float = 0;
      var dividendsRecieved : Float = 0;
      var totalTaxPaid : Float = 0; 
      switch (category){
        case(#Mortgage){
            mortgage += amount;
          };
          case(#Management){
            management += amount;
          };
          case(#MaintenanceTaxExempt){
            maintenanceTaxExempt += amount;
          };
          case(#MaintenanceNonTaxExempt){
            maintenanceNonTaxExempt += amount;
          };
          case(#Tax){
            totalTaxPaid += amount;
          };
          case(#Rent){
            rentRecieved += amount;
          };
          case(#CashInHVD){
            hVDCashInRecieved += amount;
          };
          case(#LiquidHVD){
            hVDTokensRecieved += amount;
          };
          case(#Investment){
            investmentsMade += amount;
          };
          case(#Dividends){
            dividendsRecieved += amount;
          };
          case(_){

          }
      };
      let paymentsToDate : InvoiceTotalsToDate  = {
        mortgage;
        maintenanceTaxExempt;
        maintenanceNonTaxExempt;
        management;
        rentRecieved;
        hVDTokensRecieved;
        hVDCashInRecieved;
        investmentsMade;
        dividendsRecieved;
        totalTaxPaid;
      };
      let newInvoicesInfo : InvoicesInfo = {
        companyId;
        allOfStatus = invoiceInfo.allOfStatus;
        reccurringSummary = invoiceInfo.reccurringSummary;
        annualCashflow = invoiceInfo.annualCashflow;
        paymentsToDate;
        allPropertyInvoices = invoiceInfo.allPropertyInvoices;
        taxByYear = invoiceInfo.taxByYear;
      };
      invoicesInfo.put(companyId, newInvoicesInfo);
      return #ok();

    }
  }
};

public func updateInvoiceTotalsToDate (companyId : Nat):async Result<(),Text>{
  switch(invoicesInfo.get(companyId)){
    case(null){
      return #err("There is no company with that Id");
    };
    case(? invoiceInfo){
      var mortgage : Float= 0;
      var maintenanceTaxExempt : Float = 0;
      var maintenanceNonTaxExempt : Float = 0;
      var management : Float= 0;
      var rentRecieved : Float= 0;
      var hVDTokensRecieved : Float= 0;
      var hVDCashInRecieved : Float = 0;
      var investmentsMade : Float = 0;
      var dividendsRecieved : Float = 0;
      var totalTaxPaid : Float = 0;
      //insurance, legals and stamp not utilised
      for(vals in invoiceInfo.allPropertyInvoices.vals()){
        switch(vals.category){
          case(#Mortgage){
            mortgage += vals.content.amount;
          };
          case(#Management){
            management += vals.content.amount;
          };
          case(#MaintenanceTaxExempt){
            maintenanceTaxExempt += vals.content.amount;
          };
          case(#MaintenanceNonTaxExempt){
            maintenanceNonTaxExempt += vals.content.amount;
          };
          case(#Tax){
            totalTaxPaid += vals.content.amount;
          };
          case(#Rent){
            rentRecieved += vals.content.amount;
          };
          case(#CashInHVD){
            hVDCashInRecieved += vals.content.amount;
          };
          case(#LiquidHVD){
            hVDTokensRecieved += vals.content.amount;
          };
          case(#Investment){
            investmentsMade += vals.content.amount;
          };
          case(#Dividends){
            dividendsRecieved += vals.content.amount;
          };
          case(_){

          }
        }
      };
      let paymentsToDate : InvoiceTotalsToDate  = {
        mortgage;
        maintenanceTaxExempt;
        maintenanceNonTaxExempt;
        management;
        rentRecieved;
        hVDTokensRecieved;
        hVDCashInRecieved;
        investmentsMade;
        dividendsRecieved;
        totalTaxPaid;
      };
      let newInvoicesInfo : InvoicesInfo = {
        companyId;
        allOfStatus = invoiceInfo.allOfStatus;
        reccurringSummary = invoiceInfo.reccurringSummary;
        annualCashflow = invoiceInfo.annualCashflow;
        paymentsToDate;
        allPropertyInvoices = invoiceInfo.allPropertyInvoices;
        taxByYear = invoiceInfo.taxByYear;
      };
      invoicesInfo.put(companyId, newInvoicesInfo);
      return #ok();
    };
  };
};
//This function is called everytime an invoice is paid
public func updateInvoicesPaidThisYear (companyId : Nat, amount : Float, category : InvoiceCategory): async Result<(),Text>{
  switch(invoicesInfo.get(companyId)){
    case(null){
      return #err("There is no company with that id");
    };
    case(? invoiceInfo){
      var annualIncomeRent = invoiceInfo.annualCashflow.annualIncomeRent;
      var annualIncomeSellingHVD = invoiceInfo.annualCashflow.annualIncomeSellingHVD;
      var annualMaintenanceTaxExempt = invoiceInfo.annualCashflow.annualMaintenanceTaxExempt;
      var annualMaintenanceTaxNonExempt = invoiceInfo.annualCashflow.annualMaintenanceTaxNonExempt;
      var annualManagement = invoiceInfo.annualCashflow.annualManagement;
      var annualMortgage = invoiceInfo.annualCashflow.annualMortgage;
      var annualOther = invoiceInfo.annualCashflow.annualOther; 

      switch(category){
        case(#Mortgage){ annualMortgage += amount; };
        case(#Management){ annualManagement += amount; };
        case(#MaintenanceTaxExempt){ annualMaintenanceTaxExempt += amount; };
        case(#MaintenanceNonTaxExempt){ annualMaintenanceTaxNonExempt += amount; };
        case(#Rent){ annualIncomeRent += amount; };
        case(#CashInHVD){ annualIncomeSellingHVD += amount;};
        case(_){ annualOther += amount;};
      };

      let annualCashflow : InvoicesPaidThisTaxYear = {
        annualIncomeRent;
        annualIncomeSellingHVD;
        annualMaintenanceTaxExempt;
        annualMaintenanceTaxNonExempt; 
        annualManagement;
        annualMortgage; 
        annualOther;
      };

      let newInvoiceInfo : InvoicesInfo = {
        companyId;
        allOfStatus = invoiceInfo.allOfStatus;
        reccurringSummary = invoiceInfo.reccurringSummary;
        annualCashflow;
        paymentsToDate = invoiceInfo.paymentsToDate;
        allPropertyInvoices = invoiceInfo.allPropertyInvoices;
        taxByYear = invoiceInfo.taxByYear;
      };

      invoicesInfo.put(companyId,newInvoiceInfo);
      return #ok();
    };
  };
};

func _calculateTax (invoiceInfo : InvoicesInfo): Float {
  //FYI haven't included other expenses here expecting them to be neglible but could check
  let annualCashflow = invoiceInfo.annualCashflow; 
  let income = annualCashflow.annualIncomeRent + annualCashflow.annualIncomeSellingHVD;
  let expenses = annualCashflow.annualMortgage + annualCashflow.annualMaintenanceTaxExempt + annualCashflow.annualManagement;
  let profit = income - expenses;
  let tax = profit * 19 / 100; 
  return tax;
};

private func endOfTaxYear (): async (){
  for(invoiceInfo in invoicesInfo.vals()){
    let taxPaid = _calculateTax(invoiceInfo); 
    
    let invoiceTax : InvoiceTaxByYear = {
      year = Time.now()/year + 1970;
      taxPaid; 
      previousAnnualSummary = invoiceInfo.annualCashflow;
    };
    
    let taxByYearBuffer = Buffer.fromArray<InvoiceTaxByYear>(invoiceInfo.taxByYear);
    taxByYearBuffer.add(invoiceTax);
    let taxByYear = Buffer.toArray(taxByYearBuffer);
    
    let resetAnnualCashflow = {
      annualIncomeRent = 0.00;
      annualIncomeSellingHVD = 0.00;
      annualMaintenanceTaxExempt = 0.00; 
      annualMaintenanceTaxNonExempt = 0.00;
      annualManagement = 0.00;
      annualMortgage = 0.00; 
      annualOther = 0.00;
    };
    
    let newInvoiceInfo : InvoicesInfo = {
      companyId = invoiceInfo.companyId;
      allOfStatus = invoiceInfo.allOfStatus;
      reccurringSummary = invoiceInfo.reccurringSummary;
      annualCashflow = resetAnnualCashflow;
      paymentsToDate = invoiceInfo.paymentsToDate;
      allPropertyInvoices = invoiceInfo.allPropertyInvoices;
      taxByYear; 
    };
    
    invoicesInfo.put(invoiceInfo.companyId, newInvoiceInfo);
  };
};

//This sets a timer that calls the endOfTaxYear function on April the 1st of every year to calculate every companies tax
let year = 31_536_000; 
let firstApril2025 = 1_743_465_600;
ignore setTimer(#seconds (firstApril2025 - Int.abs(Time.now() / 1_000_000_000) % year),  
 func () : async () {  
 ignore recurringTimer(#seconds year, endOfTaxYear);  
 await endOfTaxYear();  
 });  

};