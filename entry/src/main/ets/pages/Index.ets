//定义和实例化类
class Animal {
  name: string = 'DefaultName';
  sound?: string;

  constructor(name: string, sound?: string) {
    this.name = name;
    this.sound = sound;
  }

  getSound(): string {
    return this.sound ?? '无声音';
  }
}

let myAnimal: Animal = new Animal('Kitty', 'Meow');
console.log('姓名:', myAnimal.name.length);
console.log('声音:', myAnimal.getSound().length);


///////////////////////////////////////////////////////////////
//使用构造函数初始化对象
interface IFood {
  name: string;
  price: number;
  desc: string;
}

class Dish {
  name: string;
  price: number;
  desc: string;

  constructor(paramsObj: IFood) {
    this.name = paramsObj.name;
    this.price = paramsObj.price;
    this.desc = paramsObj.desc;
  }
}

let dish1: Dish = new Dish({
  name: '红烧肉',
  desc: '美味',
  price: 25
});
console.log('名称:', dish1.name);

////////////////////////////////////////////
//在类中定义方法
class User {
  name: string;
  age: number;

  constructor(name: string, age: number) {
    this.name = name;
    this.age = age;
  }

  sayHi(yourName: string) {
    console.log(`Hello, ${yourName}, I am ${this.name}.`);
  }

  sing() {
    return 'Happy Birthday';
  }
}

let user1: User = new User('Alice', 30);
user1.sayHi('Bob');

///////////////////////////////////////////////////////////
//使用静态属性和方法
class Device {
  static version: string = '1.0';
  static getRandom(): number {
    return Math.random();
  }
}

console.log('Device version:', Device.version);
console.log('Random number:', Device.getRandom());

///////////////////////////////////////////
///////////继承
//类的继承
class Person {
  name: string;
  age: number;

  constructor(name: string, age: number) {
    this.name = name;
    this.age = age;
  }

  sayHi() {
    console.log(`Hi, I am ${this.name} and I am ${this.age} years old.`);
  }
}

class Student extends Person {
  grade: string;

  constructor(name: string, age: number, grade: string) {
    super(name, age);
    this.grade = grade;
  }

  study() {
    console.log('I am a student and I love studying.');
  }

  sayHi() {
    super.sayHi();
    console.log(`I am in ${this.grade} grade.`);
  }
}

let student1: Student = new Student('John', 20, '10th');
student1.sayHi();
student1.study();

//实例化和类型检查
let student: Student = new Student('John', 20, '10th');
console.log('Is student an instance of Student:', student instanceof Student);
console.log('Is student an instance of Person:', student instanceof Person);

/////////////////////////////////////////////////修饰符
//使用修饰符
class Pet {
  name: string;
  readonly legs: number = 4;
  constructor(name: string) {
    this.name = name;
  }
}

let pet1 = new Pet('Buddy');
pet1.name = 'Max'; // OK
// pet1.legs = 6; // Error: Cannot assign to 'legs' because it is a read-only property.
console.log('Pet name:', pet1.name);
