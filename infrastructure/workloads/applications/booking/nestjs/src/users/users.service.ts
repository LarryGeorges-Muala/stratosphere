import { Injectable, UnauthorizedException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Users } from './entities/users.entity';
import { Repository } from 'typeorm';
import { CreateUserDto } from './dto/create-user.dto';
import { UpdateUserDto } from './dto/update-user.dto';
import { JwtService } from '@nestjs/jwt';

/* TEST DATA */
export type User = {
  userId: number;
  username: string;
  password: string;
}

const users: User[] = [
  {
    userId: 1,
    username: 'One',
    password: '',
  },
  {
    userId: 2,
    username: 'Two',
    password: '',
  },
];
/* END TEST DATA */

@Injectable()
export class UsersService {

  constructor(
    @InjectRepository(Users)
    private readonly usersRepository: Repository<Users>,
    private jwtService: JwtService,
  ) {}

  async findUserByName(username: string): Promise<User | undefined> {
    return users.find((user) => user.username === username);
  }

  async findUserByEmail(username: string): Promise<User | undefined> {
    return users.find((user) => user.username === username);
  }

  async create(createUserDto: CreateUserDto) {
    // Password encrypt
    createUserDto.password = btoa(createUserDto.password);

    const user = this.usersRepository.save(
      this.usersRepository.create(createUserDto)
    );

    const tokenPayload = {
      sub: createUserDto.email,
      username: createUserDto.email,
    };

    const accessToken = await this.jwtService.signAsync(tokenPayload);
  
    return {
      accessToken,
      username: createUserDto.email,
      userId: createUserDto.email
    };
  }

  async login(body: any) {
    const email = body.email;
    // Password encrypt
    const password = btoa(body.password);
    const accessClient = body.accessClient;

    return await this.usersRepository.find(
      {
        where:{email},
        select: {
          id: true,
          title: true,
          firstname: true,
          surname: true,
          email: true,
          phone: true,
          password: true,
        },
      }
    ).then(
      async (users) => {
        const user = users[0];
        if (password === user.password) {
          const tokenPayload = {
            sub: user.email,
            username: user.email,
          };

          const accessToken = await this.jwtService.signAsync(tokenPayload);

          return {
            accessToken,
            accessClient: accessClient,
            username: user.email,
            userId: user.email,
            email: user.email,
            firstname: user.firstname,
            surname: user.surname,
            title: user.title,
            phone: user.phone,
            valid: true
          };
        } else {
          return {
            valid: false
          };
        }
      }
    ).catch(
      (error) => {
        console.error('Error fetching users:', error);
        return {
          valid: false
        };
      }
    );
  }

  async resetPassword(body: any) {
    const email = body.email;
    // Password encrypt
    const password = btoa(body.password);

    return await this.usersRepository.find(
      {
        where:{email},
        select: {
          id: true,
          email: true,
          password: true,
        },
      }
    ).then(
      async (users) => {
        const user = users[0];
        user.password = password;
        await this.usersRepository.save(user);
        return {
          valid: true
        };
      }
    ).catch(
      (error) => {
        console.error('Error resetting users:', error);
        return {
          valid: false
        };
      }
    );
  }

  async updateProfile(body: any) {
    const email = body.email;

    return await this.usersRepository.find(
      {
        where:{email},
        select: {
          id: true,
          email: true,
          password: true,
        },
      }
    ).then(
      async (users) => {
        const user = users[0];

        if (Object.hasOwn(body, 'email')) {
          user.email = body.email;
        }
        if (Object.hasOwn(body, 'firstname')) {
          user.firstname = body.firstname;
        }
        if (Object.hasOwn(body, 'surname')) {
          user.surname = body.surname;
        }
        if (Object.hasOwn(body, 'title')) {
          user.title = body.title;
        }
        if (Object.hasOwn(body, 'phone')) {
          user.phone = body.phone;
        }

        await this.usersRepository.save(user);
        return {
          valid: true
        };
      }
    ).catch(
      (error) => {
        console.error('Error resetting users:', error);
        return {
          valid: false
        };
      }
    );
  }

  findAll() {
    return this.usersRepository.find();
  }

  findOneByEmail(email: string) {
    return this.usersRepository.find({ where:{email} });
  }

  findOne(id: number) {
    return `This action returns a #${id} user`;
  }

  update(id: number, updateUserDto: UpdateUserDto) {
    return `This action updates a #${id} user`;
  }

  remove(id: number) {
    return `This action removes a #${id} user`;
  }

}
