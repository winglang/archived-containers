bring "cdktf" as cdktf99;
bring "@cdktf/provider-aws" as aws99;

class Aws {
  pub static getOrCreate(scope: std.IResource): Aws {
    let stack = cdktf99.TerraformStack.of(scope);
    let id = "WingAwsUtil";
    let existing: Aws? = unsafeCast(stack.node.tryFindChild(id));
    return (existing ?? new Aws() as id in stack);
  }

  regionData: aws99.dataAwsRegion.DataAwsRegion;
  accountData: aws99.dataAwsCallerIdentity.DataAwsCallerIdentity;


  init() { 
    this.regionData = new aws99.dataAwsRegion.DataAwsRegion();
    this.accountData = new aws99.dataAwsCallerIdentity.DataAwsCallerIdentity();
  }

  pub region(): str {
    return this.regionData.name;
  }

  pub accountId(): str {
    return this.accountData.accountId;
  }
}