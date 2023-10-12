bring "../tf-aws/ecr.w" as ecr2;

class Test {
  init() {
    let x = ecr2.EcrRepository.getOrCreate(this);
    x.publish(Test.dirname() + "/test/my-app", "t3");
  }

  extern "../util.js" static dirname(): str;
}

new Test();